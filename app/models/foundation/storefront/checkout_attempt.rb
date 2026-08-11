# frozen_string_literal: true

module Foundation
  module Storefront
    class CheckoutAttempt < ApplicationRecord
      self.table_name = "storefront_checkout_attempts"

      validates :key_digest, presence: true
      validates :kind, inclusion: { in: %w[session ip] }
    end
  end
end
