# frozen_string_literal: true

module Foundation
  module Native
    # Versioned, per-platform Hotwire Native path configuration.
    # Ordinary browsers receive 404; only a detected native shell may read it.
    class PathConfigurationsController < BaseController
      before_action :require_native_shell!

      def show
        document = PathConfiguration.new(
          platform: params[:platform],
          version: params[:version]
        )
        return head :not_found unless document.supported?

        expires_in 5.minutes, public: false
        render json: document.as_json, content_type: "application/json"
      end
    end
  end
end
