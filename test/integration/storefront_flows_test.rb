require "test_helper"

class StorefrontFlowsTest < ActionDispatch::IntegrationTest
  test "catalog cart and checkout routes belong to application controllers" do
    product = create_storefront_product
    assert_equal "foundation/storefront/products", Rails.application.routes.recognize_path("/storefront/products")[:controller]
    assert_equal "foundation/storefront/carts", Rails.application.routes.recognize_path("/storefront/cart")[:controller]
    assert_equal "foundation/storefront/stripe_webhooks",
      Rails.application.routes.recognize_path("/storefront/stripe/webhook", method: :post)[:controller]

    get storefront_products_path
    assert_response :success
    assert_select ".storefront-product-card", minimum: 1
    post items_storefront_cart_path(product), params: { quantity: 2 }
    assert_redirected_to storefront_cart_path
    get storefront_cart_path
    assert_response :success
    assert_select "input[name=quantity][value='2']"
  end

  test "catalog page is bounded and paginated" do
    25.times { |index| create_storefront_product(position: index) }
    get storefront_products_path
    assert_response :success
    assert_select ".storefront-product-card", count: 24
    assert_select "a[href='#{storefront_products_path(page: 2)}']", text: "Next"
  end

  test "generic Active Storage upload routes are not exposed" do
    post "/rails/active_storage/direct_uploads", params: { blob: { filename: "x.png" } }
    assert_response :not_found
  end

  test "guest checkout requires explicit legal assent" do
    product = create_storefront_product
    post items_storefront_cart_path(product), params: { quantity: 1 }
    assert_no_difference -> { Foundation::Storefront::Order.count } do
      post storefront_checkout_path, params: { checkout: { email: "buyer@example.com", legal_assent: "0" } }
    end
    assert_response :unprocessable_content
    assert_includes response.body, "accept the Terms and Privacy Policy"
  end

  test "preview simulator is conspicuous cardless and idempotent" do
    product = create_storefront_product(inventory_quantity: 2)
    with_env("VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => "simulator") do
      post items_storefront_cart_path(product), params: { quantity: 1 }
      post storefront_checkout_path, params: { checkout: { email: "guest@example.com", legal_assent: "1" } }
      order = Foundation::Storefront::Order.order(:id).last
      assert_redirected_to %r{/storefront/simulate/#{order.public_reference}}
      token = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("access_token")

      follow_redirect!
      assert_response :success
      assert_select ".storefront-simulation-banner", text: /no money moves/i
      assert_select "input[name*='card'], input[name*='cvc'], input[name*='security']", count: 0

      assert_enqueued_jobs 1, only: Foundation::Storefront::OrderReceiptJob do
        post storefront_simulate_path(order.public_reference), params: { access_token: token }
      end
      assert_predicate order.reload, :fulfilled?
      assert_predicate order, :simulated?
      assert_equal 1, product.reload.inventory_quantity
      assert_no_enqueued_jobs do
        post storefront_simulate_path(order.public_reference), params: { access_token: token }
      end
      assert_equal 1, Foundation::Storefront::PaymentEvent.where(provider: "preview_simulator").count
    end
  end

  test "simulator is not routable outside explicit preview" do
    order = create_storefront_order
    token = Foundation::Storefront::ReceiptAccess.token_for(order)
    with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_PREVIEW_PAYMENT_MODE" => nil) do
      get storefront_simulate_path(order.public_reference), params: { access_token: token }
      assert_response :not_found
    end
  end

  test "receipt rejects enumeration and matching-email account" do
    order = create_storefront_order(email: users(:confirmed).email)
    get storefront_order_path(order.public_reference)
    assert_response :not_found

    post user_session_path, params: { user: { email: users(:confirmed).email, password: "correct horse battery" } }
    get storefront_order_path(order.public_reference)
    assert_response :not_found

    token = Foundation::Storefront::ReceiptAccess.token_for(order)
    get storefront_order_path(order.public_reference), params: { access_token: token }
    assert_response :success
    assert_select "a", text: "Terms of Service"
    assert_select "a", text: "Privacy Policy"
  end

  test "browser receipt redirect never fulfills a pending order" do
    order = create_storefront_order
    token = Foundation::Storefront::ReceiptAccess.token_for(order)
    get storefront_order_path(order.public_reference), params: { access_token: token }
    assert_response :success
    assert_predicate order.reload, :pending?
    assert_nil order.paid_at
  end

  test "official Stripe signature verification accepts generated header and rejects tampering" do
    secret = "whsec_generated_test_secret"
    payload = { id: "evt_ignored", object: "event", type: "customer.created",
                data: { object: { id: "cus_test" } } }.to_json
    timestamp = Time.now
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    header = Stripe::Webhook::Signature.generate_header(timestamp, signature)

    with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_STRIPE_MODE" => "test",
      "STOREFRONT_STRIPE_SECRET_KEY" => "sk_test_generated",
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => secret) do
      post storefront_stripe_webhook_path, params: payload,
        headers: { "Content-Type" => "application/json", "Stripe-Signature" => header }
      assert_response :ok
      assert_equal "ignored", Foundation::Storefront::PaymentEvent.find_by!(provider_event_id: "evt_ignored").status

      post storefront_stripe_webhook_path, params: "#{payload} ",
        headers: { "Content-Type" => "application/json", "Stripe-Signature" => header }
      assert_response :bad_request
    end
  end

  test "webhook rejects oversized body before signature processing" do
    payload = "x" * (Foundation::Storefront::StripeWebhooksController::MAX_PAYLOAD_BYTES + 1)
    with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_STRIPE_MODE" => "test",
      "STOREFRONT_STRIPE_SECRET_KEY" => "sk_test_body_bound",
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => "whsec_body_bound") do
      assert_no_difference -> { Foundation::Storefront::PaymentEvent.count } do
        post storefront_stripe_webhook_path, params: payload, headers: { "Content-Type" => "application/json" }
      end
      assert_response 413
    end
  end

  test "webhook is 404 in simulator or without readiness" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => "simulator") do
      post storefront_stripe_webhook_path
      assert_response :not_found
    end
    with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_STRIPE_SECRET_KEY" => nil,
      "STRIPE_PRIVATE_KEY" => nil, "STOREFRONT_STRIPE_WEBHOOK_SECRET" => nil) do
      post storefront_stripe_webhook_path
      assert_response :not_found
    end

    config = Rails.configuration.x.foundation
    previous = config[:storefront_enabled]
    config[:storefront_enabled] = false
    with_env("VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => nil,
      "STOREFRONT_STRIPE_SECRET_KEY" => nil, "STOREFRONT_STRIPE_WEBHOOK_SECRET" => nil) do
      post storefront_stripe_webhook_path
      assert_response :not_found
    end
  ensure
    config[:storefront_enabled] = previous if defined?(config) && config
  end

  test "signature-verified settlement route remains reachable after UI disable" do
    secret = "whsec_settlement_safe_value"
    payload = { id: "evt_disabled_ignored", object: "event", type: "customer.created",
                data: { object: { id: "cus_disabled" } } }.to_json
    timestamp = Time.now
    header = Stripe::Webhook::Signature.generate_header(
      timestamp, Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    )
    config = Rails.configuration.x.foundation
    previous = config[:storefront_enabled]
    config[:storefront_enabled] = false
    with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_STRIPE_MODE" => "test",
      "STOREFRONT_STRIPE_SECRET_KEY" => "sk_test_settlement_safe",
      "STOREFRONT_STRIPE_WEBHOOK_SECRET" => secret) do
      post storefront_stripe_webhook_path, params: payload,
        headers: { "Content-Type" => "application/json", "Stripe-Signature" => header }
      assert_response :ok
    end
  ensure
    config[:storefront_enabled] = previous
  end

  test "disabled semantics fail closed and remove UI affordances" do
    config = Rails.configuration.x.foundation
    previous = config[:storefront_enabled]
    config[:storefront_enabled] = false
    get storefront_products_path
    assert_response :not_found
    get pricing_path
    assert_response :success
    assert_select "a[href='#{storefront_products_path}']", count: 0
  ensure
    config[:storefront_enabled] = previous
  end

  test "expired capability retry returns a safe order response" do
    product = create_storefront_product
    with_env("VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => "simulator") do
      post items_storefront_cart_path(product), params: { quantity: 1 }
      post storefront_checkout_path, params: { checkout: { email: "expiry@example.com", legal_assent: "1" } }
    end
    order = Foundation::Storefront::Order.order(:id).last
    travel_to(order.reservation_expires_at + 1.second) do
      with_env("VELA_HOLODEX_PREVIEW" => nil, "STOREFRONT_STRIPE_MODE" => "test",
        "STOREFRONT_STRIPE_SECRET_KEY" => "sk_test_expiry_safe",
        "STOREFRONT_STRIPE_WEBHOOK_SECRET" => "whsec_expiry_safe") do
        post storefront_checkout_retry_path
        assert_redirected_to %r{/storefront/orders/#{order.public_reference}}
      end
    end
  end
end
