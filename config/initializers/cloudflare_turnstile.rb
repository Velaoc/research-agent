# Cloudflare Turnstile bot challenge (SPEC M2.2), applied to registration and
# password-reset requests via `validate_cloudflare_turnstile` in the Devise
# subclass controllers.
#
# Modes:
# - Keys present (real deployments): the live widget renders and server-side
#   validation runs against Cloudflare, failing open on network errors so an
#   outage never locks humans out.
# - Development without keys: a mock widget renders and validation checks the
#   mock token, so the flow stays visible while working locally.
# - Test, and any environment without keys (e.g. offline previews): fully
#   disabled — no widget, validation always passes.
turnstile_keys_present =
  ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"].present? && ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"].present?

RailsCloudflareTurnstile.configure do |config|
  config.site_key = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
  config.secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
  config.enabled = turnstile_keys_present && !Rails.env.test?
  config.mock_enabled = Rails.env.development? && !turnstile_keys_present
  config.fail_open = true
  config.size = :flexible
end
