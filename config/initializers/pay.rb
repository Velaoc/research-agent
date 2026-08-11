# frozen_string_literal: true

# Pay owns the local billing ledger and processes Stripe webhooks at
# /pay/webhooks/stripe. Credentials are read by Pay from Rails credentials or
# STRIPE_* environment variables; none are committed to this foundation.
Pay.setup do |config|
  identity = Rails.configuration.x.foundation
  config.application_name = identity[:application_name]
  config.business_name = identity[:application_name]
  config.support_email = identity[:support_email]
  config.parent_mailer = "ApplicationMailer"
  config.default_plan_name = "default"
  config.enabled_processors = [ :stripe ]
end
