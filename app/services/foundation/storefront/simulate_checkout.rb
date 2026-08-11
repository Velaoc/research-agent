# frozen_string_literal: true

module Foundation
  module Storefront
    class SimulateCheckout
      class Unavailable < StandardError; end

      def self.call(order)
        raise Unavailable, "The checkout simulator is available only in preview." unless Foundation.storefront_simulator?
        raise Order::InvalidTransition, "This reservation expired." if order.reservation_expires_at <= Time.current

        event_id = "simulation_#{order.public_reference}"
        event = PaymentEvent.create_or_find_by!(provider: "preview_simulator", provider_event_id: event_id) do |record|
          record.order = order
          record.event_type = "preview.checkout.confirmed"
          record.status = "received"
          record.provider_payment_id = "simulation_payment_#{order.public_reference}"
          record.payload_digest = Digest::SHA256.hexdigest(event_id)
        end
        return order if event.processed? && order.reload.fulfilled?

        FulfillOrder.call(
          order: order,
          session_id: nil,
          payment_id: "simulation_payment_#{order.public_reference}",
          simulated: true
        )
        event.update!(status: "processed", processed_at: Time.current)
        order
      end
    end
  end
end
