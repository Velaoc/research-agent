module Foundation
  # Registry of the OAuth providers this template knows how to speak to,
  # and whether each one currently has credentials. The environment variable
  # names listed here must stay in sync with the omniauth registration block
  # in config/initializers/devise.rb.
  module Oauth
    PROVIDERS = {
      google_oauth2: {
        label: "Google",
        env: %w[GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET]
      },
      github: {
        label: "GitHub",
        env: %w[GITHUB_OAUTH_CLIENT_ID GITHUB_OAUTH_CLIENT_SECRET]
      }
    }.freeze

    # A provider counts as configured only when its full credential pair is
    # present. Checked per request (not captured at boot) so the sign-in
    # buttons always reflect the live environment; in a real deployment this
    # matches what config/initializers/devise.rb registered anyway.
    def self.configured?(provider)
      PROVIDERS.fetch(provider.to_sym)[:env].all? { |name| ENV[name].present? }
    end

    def self.configured_providers
      PROVIDERS.keys.select { |provider| configured?(provider) }
    end

    # Human-facing name for buttons and flash messages.
    def self.label(provider)
      PROVIDERS.dig(provider.to_sym, :label) || provider.to_s.humanize
    end
  end
end
