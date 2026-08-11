# frozen_string_literal: true

module Foundation
  module Storefront
    class CartsController < BaseController
      before_action :set_product, only: %i[add update remove]

      def show
        ids = storefront_cart.keys.filter_map { |id| Integer(id, 10, exception: false) }
        @products = Product.where(id: ids).with_attached_image.index_by { |product| product.id.to_s }
        @cart = storefront_cart
      end

      def add
        quantity = parsed_quantity
        cart = storefront_cart
        if !cart.key?(@product.id.to_s) && cart.length >= CreateOrder::MAX_DISTINCT_ITEMS
          return redirect_to storefront_cart_path, alert: "A cart may contain at most #{CreateOrder::MAX_DISTINCT_ITEMS} different products."
        end
        cart[@product.id.to_s] = [ cart.fetch(@product.id.to_s, 0).to_i + quantity, 10 ].min
        rotate_storefront_checkout_nonce!
        write_storefront_cart(cart)
        redirect_to storefront_cart_path, notice: "Added #{@product.name} to your cart."
      rescue ArgumentError
        redirect_to storefront_product_path(@product), alert: "Quantity must be between 1 and 10."
      end

      def update
        cart = storefront_cart
        cart[@product.id.to_s] = parsed_quantity
        rotate_storefront_checkout_nonce!
        write_storefront_cart(cart)
        redirect_to storefront_cart_path, notice: "Cart updated."
      rescue ArgumentError
        redirect_to storefront_cart_path, alert: "Quantity must be between 1 and 10."
      end

      def remove
        cart = storefront_cart.except(@product.id.to_s)
        rotate_storefront_checkout_nonce!
        write_storefront_cart(cart)
        redirect_to storefront_cart_path, notice: "Item removed."
      end

      private

      def set_product
        @product = Product.catalog.find(params[:product_id])
      end

      def parsed_quantity
        quantity = Integer(params[:quantity], 10)
        raise ArgumentError unless quantity.between?(1, 10)
        quantity
      end
    end
  end
end
