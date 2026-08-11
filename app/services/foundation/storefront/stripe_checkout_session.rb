# frozen_string_literal: true

module Foundation
  module Storefront
    class StripeCheckoutSession
      Result = Data.define(:url, :session_id, :receipt_token)

      def self.call(order, gateway: StripeGateway.new)
        remote_session = nil
        readiness = Readiness.call
        raise "Storefront checkout is not ready: #{readiness.errors.join('; ')}" unless readiness.ready?
        raise "Preview checkout must use the local simulator" if Foundation.storefront_simulator?

        token = ReceiptAccess.return_token_for(order)
        order.with_lock do
          raise Order::InvalidTransition, "checkout cannot start for #{order.state}" unless order.pending?
          raise Order::InvalidTransition, "checkout reservation expired" if order.reservation_expires_at <= Time.current
          order.update!(checkout_started_at: order.checkout_started_at || Time.current)
        end
        remote_session = gateway.create_checkout_session(
          session_attributes(order, token),
          idempotency_key: "storefront_order_#{order.public_reference}"
        )
        order.with_lock do
          raise Order::InvalidTransition, "checkout cannot start for #{order.state}" unless order.pending?
          order.update!(stripe_session_id: remote_session.id)
        end
        Result.new(url: remote_session.url, session_id: remote_session.id, receipt_token: token)
      rescue Stripe::APIConnectionError, Stripe::APIError
        ExpireReservationJob.set(wait: 1.minute).perform_later(order.id) if order&.persisted? && order.checkout_started_at?
        raise
      rescue StandardError
        safely_close_failed_checkout(order, remote_session, gateway)
        raise
      end

      # Do not release on an ambiguous network/API failure: Stripe may have
      # created a payable session even when the response never reached us.
      # The signed webhook can safely bind it by opaque order reference, and
      # the expiration reconciler later releases only after confirmed expiry.

      def self.session_attributes(order, token)
        {
          mode: "payment",
          client_reference_id: order.public_reference,
          customer_email: order.email,
          line_items: order.line_items.map do |item|
            {
              price_data: {
                currency: item.currency.downcase,
                unit_amount: item.unit_price_cents,
                product_data: { name: item.name }
              },
              quantity: item.quantity
            }
          end,
          metadata: { order_reference: order.public_reference },
          payment_intent_data: { metadata: { order_reference: order.public_reference } },
          expires_at: order.reservation_expires_at.to_i,
          success_url: "#{base_url}/storefront/orders/#{order.public_reference}?access_token=#{CGI.escape(token)}",
          cancel_url: "#{base_url}/storefront/cart"
        }
      end
      private_class_method :session_attributes

      def self.base_url(runtime_config: Foundation.runtime_config)
        runtime_config.canonical_origin
      end

      def self.safely_close_failed_checkout(order, remote_session, gateway)
        return unless order&.persisted? && order.reload.pending?

        if remote_session
          expired = gateway.expire_checkout_session(remote_session.id)
          return unless expired.status == "expired"
        end
        ReleaseInventory.call(order)
      rescue Stripe::StripeError
        # Ambiguous cleanup never releases inventory while a remote session
        # might still be payable. The reconciler retains the reservation.
        nil
      end
      private_class_method :safely_close_failed_checkout
    end
  end
end
