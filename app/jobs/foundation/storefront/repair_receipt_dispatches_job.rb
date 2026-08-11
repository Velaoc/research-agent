# frozen_string_literal: true

module Foundation
  module Storefront
    class RepairReceiptDispatchesJob < ApplicationJob
      queue_as :default

      def perform
        Order.where(state: "fulfilled", receipt_sent_at: nil)
          .where("receipt_queued_at IS NULL OR receipt_queued_at < ?", ReceiptDispatcher::STALE_AFTER.ago)
          .find_each { |order| ReceiptDispatcher.call(order) }
      end
    end
  end
end
