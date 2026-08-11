# frozen_string_literal: true

module Foundation
  module Storefront
    class OrdersController < BaseController
      def show
        @order = Order.includes(:line_items).find_by!(public_reference: params[:id])
        head :not_found unless ReceiptAccess.allowed?(order: @order, user: current_user, token: params[:access_token])
      end
    end
  end
end
