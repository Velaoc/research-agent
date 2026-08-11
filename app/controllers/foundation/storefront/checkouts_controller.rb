# frozen_string_literal: true

module Foundation
  module Storefront
    class CheckoutsController < BaseController
      def show
        @pending_order, @pending_token = pending_checkout
        if @pending_order
          return redirect_to storefront_order_path(@pending_order.public_reference, access_token: @pending_token) unless @pending_order.pending?
        end
        redirect_to storefront_cart_path, alert: "Your cart is empty." if storefront_cart.blank? && !@pending_order
      end

      def create
        existing = Order.find_by(checkout_key_digest: CreateOrder.checkout_digest(storefront_checkout_nonce))
        CheckoutThrottle.check!(session_nonce: storefront_checkout_nonce, ip: request.remote_ip) unless existing
        order = CreateOrder.call(
          cart: storefront_cart,
          email: checkout_params[:email],
          user: current_user,
          legal_assent: checkout_params[:legal_assent],
          ip: request.remote_ip,
          user_agent: request.user_agent,
          checkout_nonce: storefront_checkout_nonce
        )
        token = ReceiptAccess.return_token_for(order)
        session[:storefront_pending_checkout] = { "reference" => order.public_reference, "token" => token }
        write_storefront_cart({})
        unless order.pending?
          return redirect_to storefront_order_path(order.public_reference, access_token: token)
        end
        if Foundation.storefront_simulator?
          redirect_to storefront_simulate_path(order.public_reference, access_token: token)
        else
          checkout = StripeCheckoutSession.call(order)
          redirect_to checkout.url, allow_other_host: true, status: :see_other
        end
      rescue CreateOrder::InvalidCart, CreateOrder::Unavailable, ActiveRecord::RecordInvalid => error
        flash.now[:alert] = error.message
        render :show, status: :unprocessable_content
      rescue CheckoutThrottle::Exceeded => error
        flash.now[:alert] = error.message
        render :show, status: :too_many_requests
      rescue Stripe::StripeError, RuntimeError => error
        Rails.logger.error({ event: "foundation.storefront.checkout_failed", error_class: error.class.name }.to_json)
        redirect_to storefront_checkout_path, alert: "Checkout is temporarily unavailable. Retry this same reserved order below."
      end

      def retry
        order, token = pending_checkout
        return head :not_found unless order && token && order.pending?

        checkout = StripeCheckoutSession.call(order)
        redirect_to checkout.url, allow_other_host: true, status: :see_other
      rescue Stripe::StripeError, RuntimeError => error
        Rails.logger.error({ event: "foundation.storefront.checkout_retry_failed", error_class: error.class.name }.to_json)
        redirect_to storefront_checkout_path, alert: "Checkout is still unavailable. No additional order was created."
      rescue Order::InvalidTransition
        order, token = pending_checkout
        redirect_to storefront_order_path(order.public_reference, access_token: token),
          alert: "This checkout reservation expired. Start a new cart if you still want these items."
      rescue CheckoutThrottle::Exceeded => error
        redirect_to storefront_checkout_path, alert: error.message
      end

      private

      def checkout_params
        params.fetch(:checkout, {}).permit(:email, :legal_assent)
      end

      def pending_checkout
        capability = session[:storefront_pending_checkout]
        return [ nil, nil ] unless capability.is_a?(Hash)

        order = Order.find_by(public_reference: capability["reference"])
        token = capability["token"]
        return [ nil, nil ] unless order && ReceiptAccess.allowed?(order: order, user: current_user, token: token)

        [ order, token ]
      end
    end
  end
end
