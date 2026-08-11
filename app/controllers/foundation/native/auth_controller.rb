# frozen_string_literal: true

module Foundation
  module Native
    # Native-only sign-in landing. Reuses Devise session creation so step-up
    # reauthentication and account lockout stay on the same code path as the
    # browser. Ordinary browsers receive 404.
    class AuthController < BaseController
      before_action :require_native_shell!

      def show
        if user_signed_in?
          redirect_to native_entry_path
          return
        end

        @resource = User.new
        @resource_name = :user
        @devise_mapping = Devise.mappings[:user]
      end
    end
  end
end
