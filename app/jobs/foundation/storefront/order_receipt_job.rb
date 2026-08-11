# frozen_string_literal: true

module Foundation
  module Storefront
    class OrderReceiptJob < ApplicationJob
      queue_as :default

      def perform(order_id)
        order = Order.find(order_id)
        order.with_lock do
          return unless order.fulfilled?
          return if order.receipt_sent_at?

          OrderMailer.receipt(order).deliver_now
          order.update!(receipt_sent_at: Time.current)
        end
      end
    end
  end
end
