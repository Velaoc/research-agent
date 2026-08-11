# frozen_string_literal: true

module Foundation
  module Storefront
    class StripeGateway
      def create_checkout_session(attributes, idempotency_key:)
        Stripe::Checkout::Session.create(attributes, request_options.merge(idempotency_key: idempotency_key))
      end

      def retrieve_checkout_session(id)
        Stripe::Checkout::Session.retrieve(id, request_options)
      end

      def list_line_items(id)
        Stripe::Checkout::Session.list_line_items(id, { limit: 100 }, request_options)
      end

      def expire_checkout_session(id)
        Stripe::Checkout::Session.expire(id, {}, request_options)
      end

      private

      def request_options
        { api_key: Readiness.secret_key }
      end
    end
  end
end
