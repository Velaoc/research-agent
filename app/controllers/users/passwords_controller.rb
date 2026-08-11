class Users::PasswordsController < Devise::PasswordsController
  # Cloudflare Turnstile also guards password-reset requests (SPEC M2.2) so
  # the reset mailer cannot be scripted into a spam cannon. No-op wherever
  # Turnstile is disabled (test) or unconfigured.
  before_action :validate_cloudflare_turnstile, only: :create
end
