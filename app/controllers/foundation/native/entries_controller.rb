# frozen_string_literal: true

module Foundation
  module Native
    # Shell launch handoff. Authenticated shells are told to recede/dismiss
    # the auth stack (turbo-rails native navigation); guests land on the
    # native auth screen. Browsers always 404.
    class EntriesController < BaseController
      before_action :require_native_shell!

      def show
        if user_signed_in?
          # Path helper (not _url): default_url_options pin the product host,
          # and Rails 8 rejects cross-host redirects unless explicitly allowed.
          # The shell intercepts this historical location and dismisses auth.
          redirect_to turbo_recede_historical_location_path
        else
          redirect_to native_auth_path
        end
      end
    end
  end
end
