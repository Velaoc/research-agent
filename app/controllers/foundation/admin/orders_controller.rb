# frozen_string_literal: true

module Foundation
  module Admin
    class OrdersController < BaseController
      layout "madmin/application"
      before_action :require_storefront!
      before_action :set_order, only: %i[show cancel]

      def index
        @orders = Storefront::Order.order(created_at: :desc).limit(250).includes(:line_items)
      end

      def show; end

      def cancel
        foundation_admin_audit_subject(@order)
        Storefront::CancelOrder.call(@order)
        redirect_to storefront_admin_order_path(@order), notice: "Pending order canceled and inventory released."
      rescue Storefront::Order::InvalidTransition, Storefront::CancelOrder::UnsafeToCancel, Stripe::StripeError
        foundation_admin_audit_outcome(:rejected)
        redirect_to storefront_admin_order_path(@order), alert: "Only a pending order can be canceled."
      end

      private

      def require_storefront!
        head :not_found unless Foundation.storefront_enabled?
      end

      def set_order
        @order = Storefront::Order.includes(:line_items, :payment_events).find(params[:id])
      end
    end
  end
end
