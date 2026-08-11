# frozen_string_literal: true

module Foundation
  module Native
    # Hotwire Native path-configuration documents (settings + rules).
    # Version and platform are part of the URL so a shipped binary can pin a
    # contract; unknown versions 404 rather than silently reshaping behaviour.
    #
    # Shape follows the public Hotwire Native path-configuration reference:
    # https://native.hotwired.dev/reference/path-configuration
    class PathConfiguration
      SUPPORTED_VERSION = Foundation::Native::PATH_CONFIGURATION_VERSION

      def initialize(platform:, version:)
        @platform = platform.to_s
        @version = version.to_i
      end

      def supported?
        Foundation::Native::PLATFORMS.include?(@platform) && @version == SUPPORTED_VERSION
      end

      def as_json(*)
        {
          "settings" => settings,
          "rules" => rules
        }
      end

      def to_json(*args)
        as_json.to_json(*args)
      end

      private

      def settings
        {
          "screenshots_enabled" => true,
          "registration_enabled" => true
        }
      end

      def rules
        [
          default_rule,
          auth_modal_rule,
          form_modal_rule,
          reauthentication_rule
        ]
      end

      def default_rule
        {
          "patterns" => [ ".*" ],
          "properties" => base_properties.merge(
            "context" => "default",
            "pull_to_refresh_enabled" => true
          )
        }
      end

      def auth_modal_rule
        {
          "patterns" => [
            "/users/sign_in$",
            "/users/sign_up$",
            "/users/password",
            "/users/confirmation",
            "/native/auth$",
            "/oauth/assent$"
          ],
          "properties" => base_properties.merge(
            "context" => "modal",
            "pull_to_refresh_enabled" => false
          )
        }
      end

      def form_modal_rule
        {
          "patterns" => [ "/new$", "/edit$" ],
          "properties" => base_properties.merge(
            "context" => "modal",
            "pull_to_refresh_enabled" => false
          )
        }
      end

      def reauthentication_rule
        {
          "patterns" => [ "/settings/reauthentication" ],
          "properties" => base_properties.merge(
            "context" => "modal",
            "pull_to_refresh_enabled" => false
          )
        }
      end

      def base_properties
        case @platform
        when "ios"
          {
            "presentation" => "default"
          }
        when "android"
          {
            "uri" => "hotwire://fragment/web",
            "fallback_uri" => "hotwire://fragment/web"
          }
        else
          {}
        end
      end
    end
  end
end
