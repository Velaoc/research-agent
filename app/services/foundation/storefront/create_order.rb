# frozen_string_literal: true

module Foundation
  module Storefront
    class CreateOrder
      class InvalidCart < StandardError; end
      class Unavailable < StandardError; end
      MAX_DISTINCT_ITEMS = 20

      def self.call(cart:, email:, user:, legal_assent:, ip:, user_agent:, checkout_nonce: SecureRandom.urlsafe_base64(32))
        raise InvalidCart, "Your cart is empty." if cart.blank?
        raise InvalidCart, "You must accept the Terms and Privacy Policy." unless legal_assent == "1" || legal_assent == true

        checkout_key_digest = checkout_digest(checkout_nonce)
        existing = Order.find_by(checkout_key_digest: checkout_key_digest)
        return existing if existing

        requested = normalize_cart(cart)
        raise InvalidCart, "A cart may contain at most #{MAX_DISTINCT_ITEMS} different products." if requested.length > MAX_DISTINCT_ITEMS
        order = ApplicationRecord.transaction do
          products = Product.where(id: requested.keys).order(:id).lock.index_by(&:id)
          raise InvalidCart, "A product in your cart no longer exists." unless products.size == requested.size

          # A concurrent request with this nonce may have committed while this
          # transaction waited for product locks. Reuse it before evaluating
          # availability or touching inventory again.
          replay = Order.find_by(checkout_key_digest: checkout_key_digest)
          next replay if replay

          currencies = products.values.map(&:currency).uniq
          raise InvalidCart, "All items in one order must use the same currency." unless currencies.one?

          products.each_value do |product|
            quantity = requested.fetch(product.id)
            raise Unavailable, "#{product.name} is unavailable in that quantity." unless product.active? && product.inventory_quantity >= quantity
          end

          contact_email = user ? user.email : email
          order = Order.new(
            user: user,
            checkout_key_digest: checkout_key_digest,
            email: contact_email,
            state: "pending",
            currency: currencies.first,
            subtotal_cents: 0,
            total_cents: 0,
            terms_version: Foundation::Legal::TERMS_VERSION,
            privacy_version: Foundation::Legal::PRIVACY_VERSION,
            legal_accepted_at: Time.current,
            reservation_expires_at: 45.minutes.from_now,
            acceptance_ip: ip.to_s.presence,
            acceptance_user_agent: user_agent.to_s.first(500).presence
          )

          products.values.sort_by(&:id).each do |product|
            quantity = requested.fetch(product.id)
            line_total = product.price_cents * quantity
            order.line_items.build(
              product: product,
              name: product.name,
              sku: product.sku,
              unit_price_cents: product.price_cents,
              currency: product.currency,
              quantity: quantity,
              line_total_cents: line_total
            )
            order.subtotal_cents += line_total
            order.total_cents += line_total
            product.update!(inventory_quantity: product.inventory_quantity - quantity)
          end
          order.save!
          order
        end
        begin
          ExpireReservationJob.set(wait_until: order.reservation_expires_at + 10.minutes).perform_later(order.id)
        rescue StandardError => error
          Rails.logger.error({ event: "foundation.storefront.expiry_enqueue_failed", order_id: order.id,
                               error_class: error.class.name }.to_json)
        end
        order
      rescue ActiveRecord::RecordNotUnique
        Order.find_by!(checkout_key_digest: checkout_key_digest)
      end

      def self.normalize_cart(cart)
        cart.to_h.each_with_object({}) do |(raw_id, raw_quantity), result|
          id = raw_id.is_a?(String) ? Integer(raw_id, 10) : Integer(raw_id)
          quantity = raw_quantity.is_a?(String) ? Integer(raw_quantity, 10) : Integer(raw_quantity)
          raise InvalidCart, "Quantity must be between 1 and 10." unless quantity.between?(1, 10)

          result[id] = quantity
        rescue ArgumentError, TypeError
          raise InvalidCart, "Your cart contains invalid data."
        end
      end
      private_class_method :normalize_cart

      def self.checkout_digest(checkout_nonce)
        Digest::SHA256.hexdigest(checkout_nonce.to_s)
      end
    end
  end
end
