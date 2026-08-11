# frozen_string_literal: true

module Foundation
  module Admin
    class PaymentEventsController < BaseController
      layout "madmin/application"
      before_action :require_storefront!

      def index
        @payment_events = Storefront::PaymentEvent.order(created_at: :desc).limit(250).includes(:order)
      end

      def show
        @payment_event = Storefront::PaymentEvent.find(params[:id])
      end

      private

      def require_storefront!
        head :not_found unless Foundation.storefront_enabled?
      end
    end
  end
end
