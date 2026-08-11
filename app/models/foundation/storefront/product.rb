# frozen_string_literal: true

require "uri"
require "ipaddr"

module Foundation
  module Storefront
    class Product < ApplicationRecord
      self.table_name = "storefront_products"

      IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
      MAX_IMAGE_BYTES = 8.megabytes

      has_many :line_items, class_name: "Foundation::Storefront::LineItem",
        dependent: :restrict_with_error, inverse_of: :product
      has_one_attached :image

      before_validation :normalize_fields

      validates :name, :slug, :sku, presence: true, length: { maximum: 160 }
      validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }, uniqueness: true
      validates :sku, format: { with: /\A[A-Z0-9][A-Z0-9._-]*\z/ }, uniqueness: true
      validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 999_999_999 }
      validates :inventory_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1_000_000 }
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1_000_000 }
      validates :currency, format: { with: /\A[A-Z]{3}\z/ }
      validate :safe_external_image_url
      validate :valid_image_attachment
      validate :one_image_source

      scope :catalog, -> { where(active: true).where("inventory_quantity > 0").order(:position, :name, :id) }

      def available?
        active? && inventory_quantity.positive?
      end

      def external_image?
        image_url.present?
      end

      private

      def normalize_fields
        self.name = name.to_s.strip
        self.slug = slug.to_s.strip.downcase
        self.sku = sku.to_s.strip.upcase
        self.currency = currency.to_s.strip.upcase
        self.description = description.to_s.strip
        self.image_url = image_url.to_s.strip.presence
      end

      def safe_external_image_url
        return if image_url.blank?

        uri = URI.parse(image_url)
        host = uri.host.to_s.downcase
        allowlist = Array(Rails.configuration.x.foundation[:storefront_external_image_hosts]).map(&:to_s)
        valid = uri.scheme == "https" && host.present? && allowlist.include?(host) && uri.userinfo.blank? &&
          host != "localhost" && !host.end_with?(".local", ".internal") &&
          !host.match?(/\A(?:0x)?[0-9a-f]+\z/i) && public_literal_address?(host)
        errors.add(:image_url, "must use HTTPS on an allowed external image host") unless valid
      rescue URI::InvalidURIError
        errors.add(:image_url, "must be a valid URL")
      end

      def public_literal_address?(host)
        address = IPAddr.new(host.delete_prefix("[").delete_suffix("]"))
        !(address.private? || address.loopback? || address.link_local? || address.to_i.zero?)
      rescue IPAddr::InvalidAddressError
        true
      end

      def valid_image_attachment
        return unless image.attached?

        errors.add(:image, "must be PNG, JPEG, WebP, or GIF") unless IMAGE_TYPES.include?(detected_image_content_type)
        errors.add(:image, "must be 8 MB or smaller") if image.blob.byte_size > MAX_IMAGE_BYTES
      end

      def detected_image_content_type
        change = attachment_changes["image"]
        return image.blob.content_type unless change

        attachable = change.respond_to?(:attachable, true) ? change.send(:attachable) : nil
        io = if attachable.respond_to?(:tempfile)
          attachable.tempfile
        elsif attachable.is_a?(Hash)
          attachable[:io]
        end
        return Marcel::MimeType.for(io) if io

        if image.blob.persisted?
          image.blob.open { |file| return Marcel::MimeType.for(file) }
        end
        nil
      rescue ActiveStorage::FileNotFoundError, Errno::ENOENT
        nil
      end

      def one_image_source
        errors.add(:image_url, "cannot be used together with an uploaded image") if image.attached? && image_url.present?
      end
    end
  end
end
