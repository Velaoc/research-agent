# frozen_string_literal: true

require "ipaddr"

module Foundation
  module Storefront
    class CheckoutThrottle
      WINDOW = 1.minute
      LIMITS = { "session" => 10, "ip" => 30 }.freeze
      class Exceeded < StandardError; end

      def self.check!(session_nonce:, ip:)
        normalized_ip = IPAddr.new(ip.to_s).to_s
        keys = {
          "session" => Digest::SHA256.hexdigest("session:#{session_nonce}"),
          "ip" => Digest::SHA256.hexdigest("ip:#{normalized_ip}")
        }
        CheckoutAttempt.transaction do
          keys.values.sort.each { |digest| advisory_lock!(digest) }
          keys.each do |kind, digest|
            count = CheckoutAttempt.where(kind: kind, key_digest: digest, created_at: WINDOW.ago..).count
            raise Exceeded, "Too many checkout attempts. Wait a minute and try again." if count >= LIMITS.fetch(kind)
          end
          keys.each { |kind, digest| CheckoutAttempt.create!(kind: kind, key_digest: digest, created_at: Time.current) }
        end
        true
      rescue IPAddr::InvalidAddressError
        raise Exceeded, "Checkout could not validate the request source."
      end

      def self.purge!
        CheckoutAttempt.where(created_at: ...1.day.ago).delete_all
      end

      # Bound rather than interpolated — see the note on the identical lock
      # in Foundation::Reauthentication::RateLimit.
      def self.advisory_lock!(digest)
        unsigned = digest.first(16).to_i(16)
        signed = unsigned >= (1 << 63) ? unsigned - (1 << 64) : unsigned
        CheckoutAttempt.connection.exec_query(
          "SELECT pg_advisory_xact_lock($1)",
          "advisory_lock",
          [ ActiveRecord::Relation::QueryAttribute.new(
            "key", signed, ActiveRecord::Type::BigInteger.new
          ) ]
        )
      end
      private_class_method :advisory_lock!
    end
  end
end
