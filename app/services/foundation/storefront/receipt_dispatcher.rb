# frozen_string_literal: true

module Foundation
  module Storefront
    class ReceiptDispatcher
      STALE_AFTER = 10.minutes

      def self.call(order)
        claimed = false
        claimed_at = nil
        order.with_lock do
          return order if order.receipt_sent_at?
          return order if order.receipt_queued_at && order.receipt_queued_at > STALE_AFTER.ago

          claimed_at = Time.current
          order.update!(receipt_queued_at: claimed_at)
          claimed = true
        end
        OrderReceiptJob.perform_later(order.id) if claimed
        order
      rescue StandardError
        if claimed
          order.class.where(id: order.id, receipt_sent_at: nil, receipt_queued_at: claimed_at)
            .update_all(receipt_queued_at: nil)
        end
        raise
      end
    end
  end
end
