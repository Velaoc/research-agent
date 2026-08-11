# frozen_string_literal: true

module Foundation
  module Storefront
    class SimulatorController < BaseController
      before_action :require_simulator!
      before_action :load_order

      def show; end

      def create
        SimulateCheckout.call(@order)
        redirect_to storefront_order_path(@order.public_reference, access_token: params[:access_token]),
          notice: "Simulation complete. No money moved."
      rescue SimulateCheckout::Unavailable, Order::InvalidTransition
        head :not_found
      end

      private

      def require_simulator!
        head :not_found unless Foundation.storefront_simulator?
      end

      def load_order
        @order = Order.includes(:line_items).find_by!(public_reference: params[:id])
        head :not_found unless ReceiptAccess.allowed?(order: @order, user: current_user, token: params[:access_token])
      end
    end
  end
end
