# frozen_string_literal: true

module Foundation
  module Storefront
    class Readiness
      Result = Data.define(:ready?, :mode, :errors)
      MODES = %w[live test].freeze

      def self.call(environment: ENV, runtime_config: Foundation.runtime_config, settlement: false)
        return Result.new(ready?: true, mode: "disabled", errors: []) unless Foundation.storefront_enabled? || settlement
        settlement_only = settlement && !Foundation.storefront_enabled?
        fulfillment_error = if Foundation.storefront_enabled? && Rails.configuration.x.foundation[:storefront_fulfillment_mode] != "digital"
          "storefront_fulfillment_mode must be digital; shipping is not implemented"
        end
        if runtime_config.preview?
          if runtime_config.simulator? && !settlement_only
            errors = [ fulfillment_error ].compact
            return Result.new(ready?: errors.empty?, mode: "test simulator", errors: errors)
          end
        end

        mode = environment.fetch("STOREFRONT_STRIPE_MODE",
          runtime_config.preview? ? "test" : (Rails.env.production? ? "live" : "test"))
        secret = environment["STOREFRONT_STRIPE_SECRET_KEY"].presence || environment["STRIPE_PRIVATE_KEY"].presence
        signing_secret = environment["STOREFRONT_STRIPE_WEBHOOK_SECRET"].presence
        errors = []
        errors << fulfillment_error if fulfillment_error
        errors << "STOREFRONT_STRIPE_MODE must be live or test" unless MODES.include?(mode)
        errors << "preview Stripe checkout must use test mode" if runtime_config.preview? && mode != "test"
        errors << "storefront Stripe secret key is missing or unsafe" unless valid_secret?(secret, mode)
        errors << "STOREFRONT_STRIPE_WEBHOOK_SECRET is missing or unsafe" unless valid_signing_secret?(signing_secret)
        if settlement_only
          # Outstanding orders must remain settleable even if an operator
          # disables an otherwise launch-unready interactive storefront.
        elsif runtime_config.preview_stripe? && !runtime_config.app_host_configured?
          errors << "preview Stripe checkout requires an explicit trusted APP_HOST"
        end
        if !settlement_only && (mode == "live" || Rails.env.production?)
          identity = Rails.configuration.x.foundation
          errors << "storefront commerce legal review must be completed" unless identity[:storefront_commerce_legal_reviewed] == true
          errors << "foundation application identity must be customized" if identity[:application_name] == "Application"
          errors << "foundation domain must be customized" if identity[:domain].to_s.casecmp?("example.com")
          errors << "support and legal mailboxes must be customized" if [ identity[:support_email], identity[:legal_email] ].any? { |email| email.to_s.end_with?("@example.com") }
        end

        Result.new(ready?: errors.empty?, mode: mode, errors: errors.freeze)
      end

      def self.secret_key(environment: ENV)
        environment["STOREFRONT_STRIPE_SECRET_KEY"].presence || environment["STRIPE_PRIVATE_KEY"].presence
      end

      def self.signing_secret(environment: ENV)
        environment["STOREFRONT_STRIPE_WEBHOOK_SECRET"].presence
      end

      def self.valid_secret?(value, mode)
        value.present? && safe_value?(value) && value.start_with?(mode == "live" ? "sk_live_" : "sk_test_")
      end
      private_class_method :valid_secret?

      def self.valid_signing_secret?(value)
        value.present? && safe_value?(value) && value.start_with?("whsec_")
      end
      private_class_method :valid_signing_secret?

      def self.safe_value?(value)
        downcased = value.to_s.downcase
        Foundation::PLACEHOLDER_MARKERS.none? { |marker| downcased.include?(marker) }
      end
      private_class_method :safe_value?
    end
  end
end
