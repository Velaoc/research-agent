# frozen_string_literal: true

module Foundation
  module Native
    # OS-fetched deep-link association files. Public, unauthenticated, and
    # never gated on native-shell detection — Apple and Google verifiers are
    # ordinary HTTPS clients. Contents come only from foundation.yml; missing
    # identifiers produce 404 rather than an empty or placeholder document.
    class AssociationsController < BaseController
      def apple
        document = Associations.apple_app_site_association
        return head :not_found if document.nil?

        expires_in 1.hour, public: true
        render json: document, content_type: "application/json"
      end

      def android
        document = Associations.assetlinks
        return head :not_found if document.nil?

        expires_in 1.hour, public: true
        render json: document, content_type: "application/json"
      end
    end
  end
end
