# frozen_string_literal: true

module Foundation
  module Storefront
    class StripeWebhooksController < BaseController
      MAX_PAYLOAD_BYTES = 256.kilobytes
      skip_before_action :verify_authenticity_token
      skip_before_action :require_storefront!

      def create
        return head :not_found if Foundation.storefront_simulator? || !Readiness.call(settlement: true).ready?
        return head :content_too_large unless request.content_length&.between?(1, MAX_PAYLOAD_BYTES)

        payload = request.body.read(MAX_PAYLOAD_BYTES + 1)
        return head :content_too_large if payload.bytesize > MAX_PAYLOAD_BYTES
        digest = Digest::SHA256.hexdigest(payload)
        event = Stripe::Webhook.construct_event(
          payload,
          request.headers["Stripe-Signature"],
          Readiness.signing_secret
        )
        result = StripeEventHandler.call(stripe_event: event, payload_digest: digest)
        if result.status == :rejected && result.event.nil?
          Rails.logger.warn({ event: "foundation.storefront.webhook_rejected", payload_digest: digest,
                             error_class: "malformed_event_identifier" }.to_json)
        end
        result.status == :rejected ? head(:unprocessable_content) : head(:ok)
      rescue JSON::ParserError, Stripe::SignatureVerificationError => error
        Rails.logger.warn({ event: "foundation.storefront.webhook_rejected", payload_digest: digest,
                           error_class: error.class.name }.to_json)
        head :bad_request
      rescue Stripe::StripeError => error
        Rails.logger.error({ event: "foundation.storefront.webhook_retry", payload_digest: digest,
                            error_class: error.class.name }.to_json)
        head :service_unavailable
      end
    end
  end
end
