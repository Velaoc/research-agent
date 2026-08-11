require "test_helper"

class StorefrontCheckoutServicesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  FakeCheckout = Struct.new(:id, :url, keyword_init: true)
  SdkObject = Struct.new(:status, :payment_status, :id, :client_reference_id, :metadata,
    :amount_total, :currency, :customer_details, :customer_email, :payment_intent, keyword_init: true)

  class CreateGateway
    attr_reader :attributes, :idempotency_key

    def create_checkout_session(attributes, idempotency_key:)
      @attributes = attributes
      @idempotency_key = idempotency_key
      FakeCheckout.new(id: "cs_test_server", url: "https://checkout.stripe.com/test")
    end
  end

  class EventGateway
    attr_accessor :session, :line_items, :retrieve_error

    def retrieve_checkout_session(_id)
      raise retrieve_error if retrieve_error
      SdkObject.new(**session)
    end

    def list_line_items(_id)
      line_items
    end
  end

  class CancelGateway
    attr_accessor :session, :expire_error

    def retrieve_checkout_session(_id) = SdkObject.new(**session)

    def expire_checkout_session(_id)
      raise expire_error if expire_error
      session[:status] = "expired"
      SdkObject.new(**session)
    end
  end

  setup do
    @product = create_storefront_product(price_cents: 1_599, inventory_quantity: 10)
    @order = create_storefront_order(product: @product, quantity: 2)
  end

  test "Stripe session uses only immutable server-side line items and trusted URLs" do
    gateway = CreateGateway.new
    with_stripe_test_env do
      result = Foundation::Storefront::StripeCheckoutSession.call(@order, gateway: gateway)
      assert_equal "cs_test_server", result.session_id
    end

    item = gateway.attributes.fetch(:line_items).sole
    assert_equal 1_599, item.dig(:price_data, :unit_amount)
    assert_equal 2, item[:quantity]
    assert_equal @product.name, item.dig(:price_data, :product_data, :name)
    assert_equal @order.public_reference, gateway.attributes[:client_reference_id]
    assert_equal({ order_reference: @order.public_reference }, gateway.attributes[:metadata])
    assert_match %r{\Ahttps://example\.com/storefront/orders/}, gateway.attributes[:success_url]
    assert_equal "https://example.com/storefront/cart", gateway.attributes[:cancel_url]
    assert_equal "storefront_order_#{@order.public_reference}", gateway.idempotency_key
    assert_operator gateway.attributes[:expires_at], :>=, 40.minutes.from_now.to_i
  end

  test "verified payment fulfills exactly once and queues one receipt" do
    bind_session!
    gateway = successful_event_gateway
    event = stripe_event("evt_success")

    assert_enqueued_jobs 1, only: Foundation::Storefront::OrderReceiptJob do
      result = Foundation::Storefront::StripeEventHandler.call(
        stripe_event: event, payload_digest: "a" * 64, gateway: gateway
      )
      assert_equal :processed, result.status
    end
    assert_predicate @order.reload, :fulfilled?
    assert_equal "pi_test_payment", @order.provider_payment_id

    assert_no_enqueued_jobs do
      duplicate = Foundation::Storefront::StripeEventHandler.call(
        stripe_event: event, payload_digest: "a" * 64, gateway: gateway
      )
      assert_equal :duplicate, duplicate.status
    end
  end

  test "Stripe SDK numeric integers and numeric strings both verify" do
    bind_session!
    gateway = successful_event_gateway
    gateway.session[:amount_total] = @order.total_cents.to_s
    gateway.line_items[:data].each do |item|
      item[:price][:unit_amount] = item[:price][:unit_amount].to_s
      item[:quantity] = item[:quantity].to_s
      item[:amount_total] = item[:amount_total].to_s
    end
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: stripe_event("evt_string_numbers"), payload_digest: "f" * 64, gateway: gateway
    )
    assert_equal :processed, result.status
    assert_predicate @order.reload, :fulfilled?
  end

  test "transient retrieval failure leaves event received for safe retry" do
    bind_session!
    gateway = successful_event_gateway
    gateway.retrieve_error = Stripe::APIConnectionError.new("offline")
    assert_raises(Stripe::APIConnectionError) do
      Foundation::Storefront::StripeEventHandler.call(
        stripe_event: stripe_event("evt_retry"), payload_digest: "b" * 64, gateway: gateway
      )
    end
    assert_equal "received", Foundation::Storefront::PaymentEvent.find_by!(provider_event_id: "evt_retry").status

    gateway.retrieve_error = nil
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: stripe_event("evt_retry"), payload_digest: "b" * 64, gateway: gateway
    )
    assert_equal :processed, result.status
    assert_predicate @order.reload, :fulfilled?
  end

  test "amount currency email and line item mismatches fail closed" do
    bind_session!
    {
      "amount" => ->(gateway) { gateway.session[:amount_total] += 1 },
      "currency" => ->(gateway) { gateway.session[:currency] = "eur" },
      "email" => ->(gateway) { gateway.session[:customer_details][:email] = "other@example.com" },
      "line_items" => ->(gateway) { gateway.line_items[:data][0][:quantity] = 3 }
    }.each_with_index do |(label, mutation), index|
      gateway = successful_event_gateway
      mutation.call(gateway)
      result = Foundation::Storefront::StripeEventHandler.call(
        stripe_event: stripe_event("evt_mismatch_#{index}"), payload_digest: label.ljust(64, "0"), gateway: gateway
      )
      assert_equal :rejected, result.status, label
      assert_predicate @order.reload, :pending?, label
    end
  end

  test "delayed expired event observes paid current truth and does not release" do
    bind_session!
    gateway = successful_event_gateway
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: stripe_event("evt_late_expiry", type: "checkout.session.expired"),
      payload_digest: "c" * 64, gateway: gateway
    )
    assert_equal :processed, result.status
    assert_predicate @order.reload, :fulfilled?
    assert_nil @order.inventory_released_at
    assert_equal 8, @product.reload.inventory_quantity
  end

  test "unpaid confirmed expiration releases once" do
    bind_session!
    gateway = successful_event_gateway
    gateway.session[:payment_status] = "unpaid"
    gateway.session[:status] = "expired"
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: stripe_event("evt_expired", type: "checkout.session.expired"),
      payload_digest: "d" * 64, gateway: gateway
    )
    assert_equal :released, result.status
    assert_predicate @order.reload, :canceled?
    assert_equal 10, @product.reload.inventory_quantity
  end

  test "completed delayed payment is retained then bounded reconciliation releases if still unpaid" do
    bind_session!
    gateway = successful_event_gateway
    gateway.session[:payment_status] = "unpaid"
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: stripe_event("evt_delayed"), payload_digest: "1" * 64, gateway: gateway
    )
    assert_equal :awaiting_payment, result.status
    assert_predicate @order.reload, :pending?

    travel_to 31.days.from_now do
      Foundation::Storefront::ExpireReservationJob.perform_now(@order.id, gateway: gateway)
    end
    assert_predicate @order.reload, :canceled?
    assert_equal 10, @product.reload.inventory_quantity
  end


  test "trusted scheduled reconciliation fulfills a paid session missed by webhook" do
    bind_session!
    gateway = successful_event_gateway
    travel_to 1.hour.from_now do
      Foundation::Storefront::ExpireReservationJob.perform_now(@order.id, gateway: gateway)
    end
    assert_predicate @order.reload, :fulfilled?
    event = Foundation::Storefront::PaymentEvent.find_by!(provider: "stripe_reconciliation")
    assert_equal "processed", event.status
    assert_equal "pi_test_payment", @order.provider_payment_id
  end

  test "verified settlement still fulfills an outstanding session after UI flag disables" do
    bind_session!
    config = Rails.configuration.x.foundation
    previous = config[:storefront_enabled]
    config[:storefront_enabled] = false
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: stripe_event("evt_after_disable"), payload_digest: "2" * 64,
      gateway: successful_event_gateway
    )
    assert_equal :processed, result.status
    assert_predicate @order.reload, :fulfilled?
  ensure
    config[:storefront_enabled] = previous
  end

  test "checkout retries preserve first ambiguity time and reject an expired reservation" do
    gateway = Class.new do
      def create_checkout_session(*) = raise Stripe::APIConnectionError, "ambiguous"
    end.new
    started_at = nil
    with_stripe_test_env do
      assert_raises(Stripe::APIConnectionError) { Foundation::Storefront::StripeCheckoutSession.call(@order, gateway: gateway) }
      started_at = @order.reload.checkout_started_at
      travel 5.minutes
      assert_raises(Stripe::APIConnectionError) { Foundation::Storefront::StripeCheckoutSession.call(@order, gateway: gateway) }
      assert_equal started_at, @order.reload.checkout_started_at
      travel_to(@order.reservation_expires_at + 1.second) do
        assert_raises(Foundation::Storefront::Order::InvalidTransition) do
          Foundation::Storefront::StripeCheckoutSession.call(@order, gateway: gateway)
        end
      end
    end
  end

  test "Stripe API server errors retain reservation as ambiguous" do
    gateway = Class.new do
      def create_checkout_session(*) = raise Stripe::APIError, "server failure"
    end.new
    with_stripe_test_env do
      assert_raises(Stripe::APIError) { Foundation::Storefront::StripeCheckoutSession.call(@order, gateway: gateway) }
    end
    assert_predicate @order.reload, :pending?
    assert_nil @order.inventory_released_at
    assert_predicate @order, :checkout_started_at?
  end

  test "admin cancellation confirms remote expiry and never releases on ambiguity" do
    bind_session!
    gateway = CancelGateway.new
    gateway.session = { status: "open", payment_status: "unpaid" }
    Foundation::Storefront::CancelOrder.call(@order, gateway: gateway)
    assert_predicate @order.reload, :canceled?
    assert_equal 10, @product.reload.inventory_quantity

    another = create_storefront_order(product: @product)
    another.update!(stripe_session_id: "cs_test_second", checkout_started_at: Time.current)
    gateway.session = { status: "open", payment_status: "unpaid" }
    gateway.expire_error = Stripe::APIConnectionError.new("ambiguous")
    assert_raises(Stripe::APIConnectionError) { Foundation::Storefront::CancelOrder.call(another, gateway: gateway) }
    assert_predicate another.reload, :pending?
    assert_nil another.inventory_released_at
  end

  test "blank event id is rejected predictably without an audit row" do
    result = Foundation::Storefront::StripeEventHandler.call(
      stripe_event: { id: "", type: "checkout.session.completed" }, payload_digest: "e" * 64,
      gateway: successful_event_gateway
    )
    assert_equal :rejected, result.status
    assert_nil result.event
  end

  test "readiness enforces placeholder mode and preview contracts" do
    with_env("STOREFRONT_STRIPE_SECRET_KEY" => nil, "STRIPE_PRIVATE_KEY" => nil,
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => nil, "VELA_HOLODEX_PREVIEW" => nil) do
      assert_not Foundation::Storefront::Readiness.call.ready?
    end
    with_stripe_test_env { assert Foundation::Storefront::Readiness.call.ready? }
    with_env("VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => nil,
      "STOREFRONT_STRIPE_SECRET_KEY" => nil, "STOREFRONT_STRIPE_WEBHOOK_SECRET" => nil) do
      result = Foundation::Storefront::Readiness.call
      assert result.ready?
      assert_equal "test simulator", result.mode
    end
    with_env("VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => "stripe",
      "STOREFRONT_STRIPE_MODE" => "live", "STOREFRONT_STRIPE_SECRET_KEY" => "sk_live_valid",
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => "whsec_valid") do
      assert_not Foundation::Storefront::Readiness.call.ready?
    end
  end

  test "checkout origin comes only from validated runtime configuration" do
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime_config({ "APP_HOST" => "http://example.com" }, rails_environment: :production)
    end
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime_config({ "APP_HOST" => "https://evil.example/path" }, rails_environment: :production)
    end
    # A Stripe return URL can never be moved off the product's own domain.
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime_config({ "APP_HOST" => "https://other.example" }, rails_environment: :production)
    end
    assert_equal "https://example.com",
      Foundation::Storefront::StripeCheckoutSession.base_url(
        runtime_config: runtime_config({ "APP_HOST" => "https://example.com" }, rails_environment: :production)
      )
    preview = runtime_config({ "APP_HOST" => "preview.holodex.test", "VELA_HOLODEX_PREVIEW" => "1" })
    assert_equal "https://preview.holodex.test",
      Foundation::Storefront::StripeCheckoutSession.base_url(runtime_config: preview)
  end

  test "settlement readiness bypasses disabled launch placeholders but requires keys" do
    config = Rails.configuration.x.foundation
    previous = config[:storefront_enabled]
    config[:storefront_enabled] = false
    environment = {
      "STOREFRONT_STRIPE_MODE" => "live",
      "STOREFRONT_STRIPE_SECRET_KEY" => "sk_live_settlement_safe",
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => "whsec_settlement_safe"
    }
    assert Foundation::Storefront::Readiness.call(environment: environment, settlement: true).ready?
    environment.delete("STOREFRONT_STRIPE_WEBHOOK_SECRET")
    assert_not Foundation::Storefront::Readiness.call(environment: environment, settlement: true).ready?
  ensure
    config[:storefront_enabled] = previous
  end

  private

  def runtime_config(environment, rails_environment: :test)
    Foundation::RuntimeConfig.new(
      environment: environment,
      foundation: Rails.configuration.x.foundation,
      rails_environment: rails_environment
    )
  end

  def bind_session!
    @order.update!(stripe_session_id: "cs_test_order", checkout_started_at: Time.current)
  end

  def successful_event_gateway
    EventGateway.new.tap do |gateway|
      gateway.session = {
        id: "cs_test_order", client_reference_id: @order.public_reference,
        metadata: { order_reference: @order.public_reference }, payment_status: "paid",
        status: "complete", amount_total: @order.total_cents, currency: "usd",
        customer_details: { email: @order.email }, payment_intent: "pi_test_payment"
      }
      gateway.line_items = { data: @order.line_items.map { |item|
        { description: item.name, price: { unit_amount: item.unit_price_cents, currency: item.currency.downcase },
          quantity: item.quantity, amount_total: item.line_total_cents }
      } }
    end
  end

  def stripe_event(id, type: "checkout.session.completed")
    { id: id, type: type, data: { object: { id: "cs_test_order" } } }
  end

  def with_stripe_test_env(&block)
    with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_STRIPE_MODE" => "test",
      "STOREFRONT_STRIPE_SECRET_KEY" => "sk_test_valid_key",
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => "whsec_valid_secret", &block)
  end
end
