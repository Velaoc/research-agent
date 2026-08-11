# frozen_string_literal: true

module Foundation
  module Storefront
    class ReceiptAccess
      PURPOSE = "storefront-receipt"
      LIFETIME = 24.hours

      def self.token_for(order)
        verifier.generate(order.public_reference, purpose: PURPOSE, expires_in: LIFETIME)
      end

      # Checkout creation retries must send byte-identical parameters for
      # Stripe's idempotency key. This browser-return token therefore has a
      # fixed expiry anchored to order creation; receipt mail gets a fresh
      # token from token_for at delivery time.
      def self.return_token_for(order)
        verifier.generate(order.public_reference, purpose: PURPOSE, expires_at: order.created_at + LIFETIME)
      end

      def self.allowed?(order:, user:, token:)
        return true if user && order.user_id == user.id
        return false if token.blank?

        ActiveSupport::SecurityUtils.secure_compare(
          verifier.verified(token, purpose: PURPOSE).to_s,
          order.public_reference
        )
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
        false
      end

      def self.verifier
        Rails.application.message_verifier(:foundation_storefront_receipt)
      end
      private_class_method :verifier
    end
  end
end
