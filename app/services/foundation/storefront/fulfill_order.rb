# frozen_string_literal: true

module Foundation
  module Storefront
    class FulfillOrder
      def self.call(order:, session_id:, payment_id:, simulated: false)
        Order.transaction do
          order.lock!
          unless order.fulfilled? && same_payment?(order, session_id, payment_id, simulated)
            raise Order::InvalidTransition, "a canceled or refunded order cannot be paid" unless order.pending? || order.paid?
            raise Order::InvalidTransition, "provider type mismatch" unless order.simulated? == simulated || order.pending?

            if order.pending?
              order.update!(
                simulated: simulated,
                stripe_session_id: simulated ? nil : session_id,
                provider_payment_id: payment_id
              )
              order.transition_to!("paid")
            end
            order.transition_to!("fulfilled") if order.paid?
          end
        end
        ReceiptDispatcher.call(order)
        order
      end

      def self.same_payment?(order, session_id, payment_id, simulated)
        order.simulated? == simulated && order.provider_payment_id == payment_id &&
          (simulated || order.stripe_session_id == session_id)
      end
      private_class_method :same_payment?
    end
  end
end
