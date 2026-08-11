# frozen_string_literal: true

module Foundation
  # Step-up reauthentication ("sudo mode"): a short trust window opened by
  # password confirmation or a forced re-prompt through an already-linked
  # OAuth provider. Controllers include this concern and call
  # require_recent_reauthentication! on sensitive mutations.
  module Reauthentication
    extend ActiveSupport::Concern

    WINDOW = 15.minutes
    SESSION_UNTIL_KEY = :sudo_until
    SESSION_RETURN_KEY = :sudo_return_to
    SESSION_OAUTH_KEY = :sudo_oauth
    GENERIC_FAILURE = "Confirmation failed. Please try again."
    ALLOWED_RETURN_PREFIXES = %w[
      /settings
      /billing
      /organizations
      /admin
      /users
      /pricing
    ].freeze

    module_function

    def safe_return_path(candidate, default:)
      return default if candidate.blank?

      value = candidate.to_s.strip
      return default if value.blank?

      if value.start_with?("/") && !value.start_with?("//") && !value.start_with?("/\\")
        path = value.split("#", 2).first.to_s
        path = path.split("?", 2).first.to_s
        return default if path.blank? || path.include?("://")
        return path if allowed_return_path?(path)
        return default
      end

      uri = URI.parse(value)
      return default unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return default if uri.host.blank?

      origin = Foundation.runtime_config.canonical_origin
      parsed_origin = URI.parse(origin)
      return default unless uri.scheme == parsed_origin.scheme
      return default unless uri.host == parsed_origin.host
      return default unless uri.port == parsed_origin.port

      path = uri.path.presence || "/"
      return default unless path.start_with?("/") && !path.start_with?("//")
      return path if allowed_return_path?(path)

      default
    rescue URI::InvalidURIError, ArgumentError
      default
    end

    def allowed_return_path?(path)
      ALLOWED_RETURN_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end
    module_function :allowed_return_path?

    def open_window?(raw)
      return false if raw.blank?

      deadline = if raw.respond_to?(:future?)
        raw
      else
        Time.zone.parse(raw.to_s)
      end
      return false if deadline.blank?

      deadline.future?
    rescue ArgumentError, TypeError
      false
    end

    def oauth_prompt_params(provider)
      case provider.to_s
      when "google_oauth2"
        { prompt: "login" }
      when "github"
        { prompt: "login" }
      else
        { prompt: "login" }
      end
    end

    included do
      helper_method :reauthenticated? if respond_to?(:helper_method)
    end

    def reauthenticated?
      Foundation::Reauthentication.open_window?(session[SESSION_UNTIL_KEY])
    end

    def require_recent_reauthentication!
      return if reauthenticated?

      # Always build host paths via the application helpers — engine controllers
      # (organizations) would otherwise resolve route names against the engine
      # and pick up stray params like :id.
      routes = Rails.application.routes.url_helpers
      session[SESSION_RETURN_KEY] = Foundation::Reauthentication.safe_return_path(
        request.fullpath,
        default: routes.settings_sessions_root_path
      )
      Foundation::Reauthentication::Audit.write(
        outcome: :gate_blocked,
        actor: current_user,
        request: request
      )
      redirect_to routes.new_reauthentication_path, alert: GENERIC_FAILURE
    end

    def grant_reauthentication_window!
      session[SESSION_UNTIL_KEY] = WINDOW.from_now
    end

    def clear_reauthentication_window!
      session.delete(SESSION_UNTIL_KEY)
    end

    def consume_reauthentication_return_to(fallback:)
      candidate = session.delete(SESSION_RETURN_KEY)
      Foundation::Reauthentication.safe_return_path(candidate, default: fallback)
    end
  end
end
