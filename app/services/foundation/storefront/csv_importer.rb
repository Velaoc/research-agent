# frozen_string_literal: true

require "bigdecimal"
require "csv"

module Foundation
  module Storefront
    class CsvImporter
      MAX_BYTES = 1.megabyte
      MAX_ROWS = 500
      REQUIRED_HEADERS = %w[name].freeze
      PRICE_HEADERS = %w[price price_cents].freeze
      OPTIONAL_HEADERS = %w[slug sku currency description image_url active position inventory_quantity].freeze
      ALLOWED_HEADERS = (REQUIRED_HEADERS + PRICE_HEADERS + OPTIONAL_HEADERS).freeze
      FORMULA_PREFIX = /\A[=+\-@]/
      MAX_PRICE_CENTS = 999_999_999
      MAX_POSITION = 1_000_000
      MAX_INVENTORY = 1_000_000

      RowResult = Data.define(:row, :slug, :status, :errors)
      Result = Data.define(:created, :updated, :errors, :rows)

      def self.call(contents)
        raise ArgumentError, "CSV is larger than 1 MB." if contents.bytesize > MAX_BYTES

        source = contents.dup.force_encoding(Encoding::UTF_8)
        raise ArgumentError, "CSV must be valid UTF-8." unless source.valid_encoding?

        table = CSV.parse(source, headers: true, liberal_parsing: false, field_size_limit: 64.kilobytes)
        validate_headers!(table.headers)
        raise ArgumentError, "CSV may contain at most #{MAX_ROWS} product rows." if table.length > MAX_ROWS

        results = table.each_with_index.map { |row, index| import_row(row, index + 2) }
        Result.new(
          created: results.count { |result| result.status == :created },
          updated: results.count { |result| result.status == :updated },
          errors: results.count { |result| result.status == :error },
          rows: results.freeze
        )
      rescue CSV::MalformedCSVError => error
        raise ArgumentError, "Malformed CSV near line #{error.line_number}."
      end

      def self.validate_headers!(headers)
        raise ArgumentError, "CSV requires a header row." if headers.blank? || headers.any?(&:nil?)
        normalized = headers.map { |header| header.to_s.strip }
        raise ArgumentError, "CSV headers must not be duplicated." unless normalized.uniq.length == normalized.length

        unknown = normalized - ALLOWED_HEADERS
        raise ArgumentError, "Unknown CSV headers: #{unknown.join(', ')}." if unknown.any?
        missing = REQUIRED_HEADERS - normalized
        raise ArgumentError, "Missing CSV headers: #{missing.join(', ')}." if missing.any?
        raise ArgumentError, "CSV requires a price or price_cents header." if (normalized & PRICE_HEADERS).empty?
      end
      private_class_method :validate_headers!

      def self.import_row(row, number)
        attributes = attributes_for(row)
        product = Product.find_or_initialize_by(slug: attributes.fetch(:slug))
        status = product.new_record? ? :created : :updated
        unless product.new_record?
          %w[sku currency description image_url active position inventory_quantity].each do |optional|
            attributes.delete(optional.to_sym) if row[optional].to_s.strip.blank?
          end
        end
        product.assign_attributes(attributes)
        product.save!
        RowResult.new(row: number, slug: product.slug, status: status, errors: [])
      rescue ActiveRecord::RecordInvalid, ArgumentError => error
        messages = error.respond_to?(:record) ? error.record.errors.full_messages : [ error.message ]
        RowResult.new(row: number, slug: row["slug"].to_s, status: :error, errors: messages)
      end
      private_class_method :import_row

      def self.attributes_for(row)
        strings = row.to_h.transform_values { |value| value.to_s.strip }
        hostile = strings.find { |_key, value| value.match?(FORMULA_PREFIX) }
        raise ArgumentError, "Spreadsheet formulas are not accepted." if hostile

        name = strings.fetch("name", "")
        raise ArgumentError, "Name is required." if name.blank?
        slug = strings["slug"].presence || name.parameterize
        raise ArgumentError, "Name must produce a valid slug." if slug.blank?

        cents = price_cents(strings)
        {
          name: name,
          slug: slug,
          sku: strings["sku"].presence || slug.upcase,
          description: strings["description"].to_s,
          price_cents: cents,
          currency: strings["currency"].presence || "USD",
          image_url: strings["image_url"].presence,
          active: boolean(strings["active"], default: true),
          position: integer(strings["position"], default: 0, name: "position"),
          inventory_quantity: integer(strings["inventory_quantity"], default: 0, name: "inventory_quantity")
        }
      end
      private_class_method :attributes_for

      def self.price_cents(strings)
        dollars = strings["price"].presence
        cents = strings["price_cents"].presence
        raise ArgumentError, "Use either price or price_cents, not both." if dollars && cents
        raise ArgumentError, "A price is required." unless dollars || cents

        if cents
          raise ArgumentError, "Price cents must be a bounded integer." unless cents.match?(/\A\d{1,12}\z/)
          value = Integer(cents, 10)
        else
          raise ArgumentError, "Price must be plain decimal notation." unless dollars.match?(/\A\d{1,7}(?:\.\d{1,2})?\z/)
          decimal = BigDecimal(dollars)
          raise ArgumentError, "Price must be finite." unless decimal.finite?
          raise ArgumentError, "Price must have no more than two decimal places." unless decimal.frac.abs * 100 == (decimal.frac.abs * 100).to_i
          value = (decimal * 100).to_i
        end
        raise ArgumentError, "Price must be zero or greater." if value.negative?
        raise ArgumentError, "Price exceeds the supported maximum." if value > MAX_PRICE_CENTS
        value
      rescue TypeError, FloatDomainError
        raise ArgumentError, "Price must be a decimal dollar value or integer cents."
      end
      private_class_method :price_cents

      def self.integer(value, default:, name:)
        return default if value.blank?
        raise ArgumentError unless value.match?(/\A\d{1,8}\z/)
        parsed = Integer(value, 10)
        maximum = name == "position" ? MAX_POSITION : MAX_INVENTORY
        raise ArgumentError if parsed > maximum
        parsed
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name.humanize} must be an integer."
      end
      private_class_method :integer

      def self.boolean(value, default:)
        return default if value.blank?
        return true if value.casecmp?("true")
        return false if value.casecmp?("false")

        raise ArgumentError, "Active must be true or false."
      end
      private_class_method :boolean
    end
  end
end
