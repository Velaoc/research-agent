# frozen_string_literal: true

module Foundation
  module Storefront
    class ReleaseInventory
      def self.call(order)
        Order.transaction do
          locked_order = Order.lock.find(order.id)
          return locked_order if locked_order.inventory_released_at?
          raise Order::InvalidTransition, "only pending orders can be canceled" unless locked_order.pending?

          product_ids = locked_order.line_items.where.not(product_id: nil).pluck(:product_id).sort
          products = Product.lock.where(id: product_ids).index_by(&:id)
          locked_order.line_items.each do |item|
            product = products[item.product_id]
            product&.update!(inventory_quantity: product.inventory_quantity + item.quantity)
          end
          locked_order.transition_to!("canceled")
          locked_order.update!(inventory_released_at: Time.current)
          locked_order
        end
      end
    end
  end
end
