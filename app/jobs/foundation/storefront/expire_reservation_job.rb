# frozen_string_literal: true

module Foundation
  module Storefront
    class ExpireReservationJob < ApplicationJob
      queue_as :default

      def perform(order_id = nil, gateway: StripeGateway.new)
        scope = Order.where(state: "pending")
        scope = scope.where(id: order_id) if order_id
        scope.where(reservation_expires_at: ..Time.current).find_each do |order|
          reconcile_or_release(order, gateway)
        end
      end

      private

      def reconcile_or_release(order, gateway)
        if order.stripe_session_id?
          session = gateway.retrieve_checkout_session(order.stripe_session_id)
          session_status = StripeEventHandler.value(session, :status).to_s
          payment_status = StripeEventHandler.value(session, :payment_status).to_s
          if payment_status == "paid"
            payment_id = StripeEventHandler.verify_checkout!(order, session, gateway.list_line_items(order.stripe_session_id))
            event = PaymentEvent.create_or_find_by!(
              provider: "stripe_reconciliation",
              provider_event_id: "reconcile_#{order.stripe_session_id}_paid"
            ) do |record|
              record.order = order
              record.event_type = "checkout.session.reconciled_paid"
              record.status = "received"
              record.provider_session_id = order.stripe_session_id
              record.provider_payment_id = payment_id
              record.payload_digest = Digest::SHA256.hexdigest("stripe-reconciliation:#{order.stripe_session_id}")
            end
            FulfillOrder.call(order: order, session_id: order.stripe_session_id, payment_id: payment_id)
            event.update!(status: "processed", processed_at: Time.current)
            return
          end
          return ReleaseInventory.call(order) if session_status == "expired"

          # Open sessions stay reserved until Stripe confirms expiry. A
          # complete delayed-payment session gets a bounded reconciliation
          # window; paid truth is validated above before recovery fulfillment.
          self.class.set(wait: 5.minutes).perform_later(order.id) if session_status == "open"
          if session_status == "complete" && payment_status == "unpaid"
            if order.checkout_started_at && order.checkout_started_at + 30.days <= Time.current
              ReleaseInventory.call(order)
            else
              self.class.set(wait: 6.hours).perform_later(order.id)
            end
          end
        elsif order.checkout_started_at?
          # An API timeout can hide a successfully created session. Stripe
          # sessions cannot remain payable beyond 24 hours, so retain this
          # ambiguous reservation for that bounded safety window.
          if order.checkout_started_at + 24.hours <= Time.current
            ReleaseInventory.call(order)
          else
            self.class.set(wait: 30.minutes).perform_later(order.id)
          end
        else
          ReleaseInventory.call(order)
        end
      rescue Stripe::StripeError
        self.class.set(wait: 5.minutes).perform_later(order.id)
      end
    end
  end
end
