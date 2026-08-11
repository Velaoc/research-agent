class Users::ConfirmationsController < Devise::ConfirmationsController
  # Confirmation resend is an unauthenticated mail trigger. Cap bursts per
  # client IP so it cannot be scripted into a delivery flood.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 5, within: 15.minutes, only: :create, store: RATE_LIMIT_STORE

  # Cloudflare Turnstile also guards confirmation resend (SPEC M2.2) so the
  # confirmation mailer cannot be scripted into a spam cannon. No-op wherever
  # Turnstile is disabled (test) or unconfigured.
  before_action :validate_cloudflare_turnstile, only: :create

  private

  # Always report success with the paranoid notice so the response cannot
  # reveal whether an address is registered (or already confirmed).
  def successfully_sent?(resource)
    resource.errors.clear
    set_flash_message! :notice, :send_paranoid_instructions
    true
  end
end
