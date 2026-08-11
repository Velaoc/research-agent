# frozen_string_literal: true

module Foundation
  module Storefront
    class PurgeUnattachedBlobsJob < ApplicationJob
      queue_as :default

      def perform
        ActiveStorage::Blob.unattached.where(created_at: ..24.hours.ago).find_each(&:purge_later)
        CheckoutThrottle.purge!
      end
    end
  end
end
