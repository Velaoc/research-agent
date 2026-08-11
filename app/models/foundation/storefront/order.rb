# frozen_string_literal: true

module Foundation
  module Storefront
    class Order < ApplicationRecord
      self.table_name = "storefront_orders"

      STATES = %w[pending paid fulfilled canceled refunded].freeze
      TRANSITIONS = {
        "pending" => %w[paid canceled],
        "paid" => %w[fulfilled refunded],
        "fulfilled" => %w[refunded],
        "canceled" => [],
        "refunded" => []
      }.freeze

      STATES.each { |value| define_method("#{value}?") { state == value } }

      belongs_to :user, optional: true, inverse_of: :storefront_orders
      has_many :line_items, class_name: "Foundation::Storefront::LineItem",
        dependent: :destroy, inverse_of: :order
      has_many :payment_events, class_name: "Foundation::Storefront::PaymentEvent",
        dependent: :nullify, inverse_of: :order

      before_validation :assign_public_reference, on: :create
      before_validation :normalize_fields

      validates :public_reference, presence: true, uniqueness: true
      validates :checkout_key_digest, presence: true, uniqueness: true
      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
      validates :state, inclusion: { in: STATES }
      validates :currency, format: { with: /\A[A-Z]{3}\z/ }
      validates :subtotal_cents, :total_cents,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :terms_version, :privacy_version, :legal_accepted_at, :reservation_expires_at, presence: true
      validates :stripe_session_id, :provider_payment_id, uniqueness: true, allow_nil: true
      validate :totals_match

      def transition_to!(new_state, at: Time.current)
        new_state = new_state.to_s
        raise InvalidTransition, "#{state} cannot transition to #{new_state}" unless TRANSITIONS.fetch(state).include?(new_state)

        attributes = { state: new_state }
        attributes["#{new_state}_at"] = at if has_attribute?("#{new_state}_at")
        update!(attributes)
      end

      class InvalidTransition < StandardError; end

      private

      def assign_public_reference
        self.public_reference ||= loop do
          candidate = SecureRandom.base58(24)
          break candidate unless self.class.exists?(public_reference: candidate)
        end
      end

      def normalize_fields
        self.email = email.to_s.strip.downcase
        self.currency = currency.to_s.strip.upcase
      end

      def totals_match
        errors.add(:total_cents, "must equal subtotal") unless total_cents == subtotal_cents
      end
    end
  end
end
