# frozen_string_literal: true

module Foundation
  module Storefront
    class PaymentEvent < ApplicationRecord
      self.table_name = "storefront_payment_events"

      STATUSES = %w[received processed rejected ignored].freeze
      STATUSES.each { |value| define_method("#{value}?") { status == value } }

      belongs_to :order, class_name: "Foundation::Storefront::Order", optional: true, inverse_of: :payment_events

      validates :provider, :provider_event_id, :event_type, :payload_digest, presence: true
      validates :provider_event_id, uniqueness: { scope: :provider }
      validates :status, inclusion: { in: STATUSES }
    end
  end
end
