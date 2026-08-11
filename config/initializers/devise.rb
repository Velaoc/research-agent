# Devise configuration, overrides only — anything not listed here runs on
# Devise's own defaults (see the devise README for the full catalogue).

require "devise/orm/active_record"

Devise.setup do |config|
  # Auth mail (confirmation, reset, unlock) comes from the operator support
  # mailbox defined in config/foundation.yml.
  config.mailer_sender = Foundation.runtime_config.mailer_from
  config.parent_mailer = "ApplicationMailer"

  # Emails are matched case-insensitively and with surrounding whitespace
  # stripped, so "  Jane@Example.COM " signs in as jane@example.com.
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]

  # Session cookies only; no credential caching for HTTP auth.
  config.skip_session_storage = [ :http_auth ]

  # Full bcrypt cost in real environments; the minimum cost in tests, where
  # hashing speed dominates suite runtime and security is irrelevant.
  config.stretches = Rails.env.test? ? 1 : 12

  # SPEC M2.1: passwords are at least 12 characters.
  config.password_length = 12..128

  # Loose shape check only (one @, no spaces); the confirmation email is the
  # real proof of deliverability.
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # Changing your email re-runs confirmation against the new address and
  # keeps the old one active until the link is clicked.
  config.reconfirmable = true

  # SPEC M2.1: lock the account after repeated failed sign-ins. Ten tries,
  # then unlock via emailed link or automatically after an hour.
  config.lock_strategy = :failed_attempts
  config.maximum_attempts = 10
  config.unlock_strategy = :both
  config.unlock_in = 1.hour

  # Password-reset links expire after six hours.
  config.reset_password_within = 6.hours

  # Signing out anywhere clears remember-me cookies on every device.
  config.expire_all_remember_me_on_sign_out = true

  # Sign-out is a DELETE (the layout uses button_to), never a crawlable GET.
  config.sign_out_via = :delete

  # Hotwire/Turbo-friendly statuses: 422 re-renders forms, 303 follows
  # redirects after non-GET requests.
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  # SPEC M3.1: OAuth providers register only when their full credential pair
  # is present in the environment, so a bare checkout boots — and hides the
  # sign-in buttons — with no OAuth setup at all. Keep the variable names in
  # sync with Foundation::Oauth::PROVIDERS (lib/foundation/oauth.rb), which
  # views and controllers use for the same check at request time.
  #
  # GitHub needs the user:email scope or it withholds the address the
  # linking rules key on; Google includes email in its default scope.
  {
    google_oauth2: { env: %w[GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET], options: {} },
    github: { env: %w[GITHUB_OAUTH_CLIENT_ID GITHUB_OAUTH_CLIENT_SECRET], options: { scope: "user:email" } }
  }.each do |provider, spec|
    id, secret = spec[:env].map { |name| ENV[name] }

    if id.present? && secret.present?
      config.omniauth provider, id, secret, spec[:options]
    elsif Rails.env.test?
      # The suite drives OmniAuth in its test mode, which never contacts a
      # provider — but callback routes only exist for registered providers,
      # so tests register everything with stand-in credentials. Button
      # visibility still follows the live ENV via Foundation::Oauth.
      config.omniauth provider, "#{provider}-test-id", "#{provider}-test-secret", spec[:options]
    end
  end
end
