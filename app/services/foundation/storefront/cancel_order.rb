# frozen_string_literal: true

module Foundation
  module Storefront
    class CancelOrder
      class UnsafeToCancel < StandardError; end

      def self.call(order, gateway: StripeGateway.new)
        order.reload
        return order if order.canceled? && order.inventory_released_at?
        raise Order::InvalidTransition, "only pending orders can be canceled" unless order.pending?

        if order.stripe_session_id?
          session = gateway.retrieve_checkout_session(order.stripe_session_id)
          raise UnsafeToCancel, "a paid checkout cannot be canceled locally" if session.payment_status == "paid"
          session = gateway.expire_checkout_session(order.stripe_session_id) unless session.status == "expired"
          raise UnsafeToCancel, "Stripe did not confirm expiration" unless session.status == "expired"
        elsif order.checkout_started_at?
          raise UnsafeToCancel, "checkout creation is still being reconciled"
        end

        ReleaseInventory.call(order)
      end
    end
  end
end
