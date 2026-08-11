# frozen_string_literal: true

module Foundation
  module Storefront
    class LineItem < ApplicationRecord
      self.table_name = "storefront_line_items"

      belongs_to :order, class_name: "Foundation::Storefront::Order", inverse_of: :line_items
      belongs_to :product, class_name: "Foundation::Storefront::Product", optional: true, inverse_of: :line_items

      attr_readonly :order_id, :product_id, :name, :sku, :unit_price_cents, :currency,
        :quantity, :line_total_cents

      validates :name, :sku, presence: true
      validates :unit_price_cents, :line_total_cents,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :quantity, numericality: { only_integer: true, in: 1..10 }
      validates :currency, format: { with: /\A[A-Z]{3}\z/ }
      validate :snapshot_total_matches

      private

      def snapshot_total_matches
        return unless unit_price_cents.is_a?(Integer) && quantity.is_a?(Integer)
        return if line_total_cents == unit_price_cents * quantity

        errors.add(:line_total_cents, "must equal unit price times quantity")
      end
    end
  end
end
