# frozen_string_literal: true

module Foundation
  # Gates native-shell-only endpoints. Detection matches turbo-rails'
  # hotwire_native_app? (UA contains "Hotwire Native" or "Turbo Native").
  # Ordinary browsers receive 404 — never alternate content — so native
  # behaviour cannot leak into the public web surface.
  module NativeShell
    extend ActiveSupport::Concern

    private

    def native_shell?
      if respond_to?(:hotwire_native_app?, true)
        hotwire_native_app?
      else
        Foundation::Native.shell?(request.user_agent)
      end
    end

    def require_native_shell!
      return if native_shell?

      head :not_found
    end
  end
end
