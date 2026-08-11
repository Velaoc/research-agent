# frozen_string_literal: true

module Foundation
  module Storefront
    class BaseController < ApplicationController
      before_action :require_storefront!

      private

      def require_storefront!
        head :not_found unless Foundation.storefront_enabled?
      end

      def storefront_cart
        raw = session[:storefront_cart]
        raw.is_a?(Hash) ? raw.transform_keys(&:to_s) : {}
      end

      def write_storefront_cart(cart)
        session[:storefront_cart] = cart.transform_keys(&:to_s).transform_values(&:to_i)
      end

      def storefront_checkout_nonce
        session[:storefront_checkout_nonce] ||= SecureRandom.urlsafe_base64(32)
      end

      def rotate_storefront_checkout_nonce!
        session[:storefront_checkout_nonce] = SecureRandom.urlsafe_base64(32)
      end
    end
  end
end
