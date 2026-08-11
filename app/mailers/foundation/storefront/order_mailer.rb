# frozen_string_literal: true

module Foundation
  module Storefront
    class OrderMailer < ApplicationMailer
      helper Foundation::StorefrontHelper

      def receipt(order)
        @order = order
        @token = ReceiptAccess.token_for(order)
        message_host = Foundation.runtime_config.url_options.fetch(:host)
        headers["Message-ID"] = "<storefront-order-#{order.public_reference}@#{message_host}>"
        mail(to: order.email, subject: "Receipt for order #{order.public_reference}")
      end
    end
  end
end
