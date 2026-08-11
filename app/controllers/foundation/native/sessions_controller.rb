# frozen_string_literal: true

module Foundation
  module Native
    # Lightweight current-user poll for the shell. Does not open or close a
    # session — it only reports whether the web view already holds one.
    # Browsers always 404.
    class SessionsController < BaseController
      before_action :require_native_shell!

      def show
        expires_now
        render json: payload, content_type: "application/json"
      end

      private

      def payload
        if user_signed_in?
          {
            "signed_in" => true,
            "user" => {
              "id" => current_user.id,
              "email" => current_user.email
            }
          }
        else
          {
            "signed_in" => false,
            "user" => nil
          }
        end
      end
    end
  end
end
