# frozen_string_literal: true

module Foundation
  module Storefront
    class StripeEventHandler
      SUCCESS_TYPES = %w[checkout.session.completed checkout.session.async_payment_succeeded].freeze
      RELEASE_TYPES = %w[checkout.session.expired checkout.session.async_payment_failed].freeze
      RELEVANT_TYPES = (SUCCESS_TYPES + RELEASE_TYPES).freeze

      Result = Data.define(:status, :order, :event)
      class VerificationError < StandardError
        attr_reader :code

        def initialize(code)
          @code = code
          super("Stripe checkout verification failed")
        end
      end

      def self.call(stripe_event:, payload_digest:, gateway: StripeGateway.new)
        event_id = value(stripe_event, :id).to_s
        event_type = value(stripe_event, :type).to_s
        return Result.new(status: :rejected, order: nil, event: nil) if event_id.blank?

        provider_event = PaymentEvent.find_or_initialize_by(
          provider: "stripe",
          provider_event_id: event_id
        )
        if provider_event.persisted? && provider_event.status != "received"
          return Result.new(status: :duplicate, order: provider_event.order, event: provider_event)
        end
        provider_event.assign_attributes(
          event_type: event_type,
          status: "received",
          payload_digest: payload_digest
        )
        provider_event.save!

        unless RELEVANT_TYPES.include?(event_type)
          provider_event.update!(status: "ignored", processed_at: Time.current)
          return Result.new(status: :ignored, order: nil, event: provider_event)
        end

        event_session = value(value(stripe_event, :data), :object)
        session_id = value(event_session, :id).to_s
        raise VerificationError, "missing_session" if session_id.blank?

        session = gateway.retrieve_checkout_session(session_id)
        order = Order.find_by(stripe_session_id: session_id)
        unless order
          reference = value(session, :client_reference_id).to_s
          order = Order.find_by(public_reference: reference, stripe_session_id: nil, state: "pending")
          order&.with_lock do
            raise VerificationError, "session_already_bound" if order.stripe_session_id.present? && order.stripe_session_id != session_id
            order.update!(stripe_session_id: session_id)
          end
        end
        raise VerificationError, "unknown_session" unless order

        provider_event.update!(order: order, provider_session_id: session_id)
        verify_identity!(order, session)

        # Event delivery order is not authoritative. A delayed "expired" or
        # async failure must not release inventory after payment succeeded.
        if RELEASE_TYPES.include?(event_type) && value(session, :payment_status).to_s != "paid"
          ReleaseInventory.call(order)
          provider_event.update!(status: "processed", processed_at: Time.current)
          return Result.new(status: :released, order: order, event: provider_event)
        end


        if event_type == "checkout.session.completed" && value(session, :payment_status).to_s == "unpaid"
          provider_event.update!(status: "processed", error_code: "awaiting_delayed_payment", processed_at: Time.current)
          ExpireReservationJob.set(wait: 30.minutes).perform_later(order.id)
          return Result.new(status: :awaiting_payment, order: order, event: provider_event)
        end

        payment_id = verify_checkout!(order, session, gateway.list_line_items(session_id))

        provider_event.update!(provider_payment_id: payment_id)
        FulfillOrder.call(order: order, session_id: session_id, payment_id: payment_id)
        provider_event.update!(status: "processed", processed_at: Time.current)
        Result.new(status: :processed, order: order, event: provider_event)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
        raise unless duplicate_event?(error, event_id)

        existing = PaymentEvent.find_by!(provider: "stripe", provider_event_id: event_id)
        return call(stripe_event: stripe_event, payload_digest: payload_digest, gateway: gateway) if existing.status == "received"

        Result.new(status: :duplicate, order: existing.order, event: existing)
      rescue VerificationError => error
        provider_event&.update!(status: "rejected", error_code: error.code, processed_at: Time.current)
        Result.new(status: :rejected, order: provider_event&.order, event: provider_event)
      rescue Order::InvalidTransition
        provider_event&.update!(status: "rejected", error_code: "invalid_order_state", processed_at: Time.current)
        Result.new(status: :rejected, order: provider_event&.order, event: provider_event)
      end

      def self.verify_checkout!(order, session, line_items)
        verify_identity!(order, session)
        verify_payment!(order, session, line_items)
        identifier(value(session, :payment_intent)).presence || raise(VerificationError, "missing_payment")
      end

      def self.verify_identity!(order, session)
        raise VerificationError, "session_mismatch" unless value(session, :id).to_s == order.stripe_session_id
        raise VerificationError, "reference_mismatch" unless value(session, :client_reference_id).to_s == order.public_reference

        metadata = value(session, :metadata)
        raise VerificationError, "metadata_mismatch" unless value(metadata, :order_reference).to_s == order.public_reference
      end
      private_class_method :verify_identity!

      def self.verify_payment!(order, session, line_items)
        raise VerificationError, "unpaid_session" unless value(session, :payment_status).to_s == "paid"
        raise VerificationError, "amount_mismatch" unless integer(value(session, :amount_total)) == order.total_cents
        raise VerificationError, "currency_mismatch" unless value(session, :currency).to_s.upcase == order.currency

        details = value(session, :customer_details)
        provider_email = value(details, :email).presence || value(session, :customer_email).presence
        raise VerificationError, "email_mismatch" unless provider_email.to_s.casecmp?(order.email)

        actual = Array(value(line_items, :data)).map do |item|
          price = value(item, :price)
          [ value(item, :description).to_s, integer(value(price, :unit_amount)),
            value(price, :currency).to_s.upcase, integer(value(item, :quantity)), integer(value(item, :amount_total)) ]
        end.sort
        expected = order.line_items.map do |item|
          [ item.name, item.unit_price_cents, item.currency, item.quantity, item.line_total_cents ]
        end.sort
        raise VerificationError, "line_items_mismatch" unless actual == expected
      end
      private_class_method :verify_payment!

      def self.value(object, key)
        return if object.nil?
        return object.public_send(key) if object.respond_to?(key)
        object[key] || object[key.to_s] if object.respond_to?(:[])
      end

      def self.identifier(object)
        object.respond_to?(:id) ? object.id.to_s : object.to_s
      end
      private_class_method :identifier

      def self.integer(value)
        value.is_a?(String) ? Integer(value, 10) : Integer(value)
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :integer

      def self.duplicate_event?(error, event_id)
        event_id.present? && PaymentEvent.exists?(provider: "stripe", provider_event_id: event_id) &&
          (error.is_a?(ActiveRecord::RecordNotUnique) || error.record.errors.of_kind?(:provider_event_id, :taken))
      end
      private_class_method :duplicate_event?
    end
  end
end
