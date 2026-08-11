require "test_helper"

class StorefrontModelsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "product normalizes currency and rejects float money" do
    product = create_storefront_product(currency: "usd")
    assert_equal "USD", product.currency

    product.price_cents = 12.5
    assert_not product.valid?
    assert product.errors.of_kind?(:price_cents, :not_an_integer)
  end

  test "database rejects negative inventory and invalid currency" do
    product = create_storefront_product
    assert_raises ActiveRecord::StatementInvalid do
      Foundation::Storefront::Product.transaction(requires_new: true) do
        product.update_columns(inventory_quantity: -1)
      end
    end
    assert_raises ActiveRecord::StatementInvalid do
      Foundation::Storefront::Product.transaction(requires_new: true) do
        product.update_columns(currency: "US")
      end
    end
  end

  test "create order snapshots trusted values and reserves inventory" do
    product = create_storefront_product(price_cents: 2_345, inventory_quantity: 4)
    order = create_storefront_order(product: product, quantity: 2)
    item = order.line_items.first

    assert_equal 4_690, order.total_cents
    assert_equal [ product.name, product.sku, 2_345, 2 ], [ item.name, item.sku, item.unit_price_cents, item.quantity ]
    assert_equal 2, product.reload.inventory_quantity
    product.update!(name: "Renamed", price_cents: 9_999)
    assert_equal [ item.name, 2_345 ], [ order.line_items.first.name, order.line_items.first.unit_price_cents ]
  end

  test "checkout nonce replay returns one database order and reserves inventory once" do
    product = create_storefront_product(inventory_quantity: 3)
    attributes = {
      cart: { product.id => 2 }, email: "replay@example.com", user: nil,
      legal_assent: "1", ip: "192.0.2.5", user_agent: "Replay test",
      checkout_nonce: "server-generated-cart-nonce"
    }
    first = Foundation::Storefront::CreateOrder.call(**attributes)
    second = Foundation::Storefront::CreateOrder.call(**attributes)
    assert_equal first.id, second.id
    assert_equal 1, Foundation::Storefront::Order.where(checkout_key_digest: first.checkout_key_digest).count
    assert_equal 1, product.reload.inventory_quantity
  end

  test "expiry enqueue failure cannot make nonce replay reserve another order" do
    product = create_storefront_product(inventory_quantity: 2)
    scheduled = Object.new
    scheduled.define_singleton_method(:perform_later) { |*| raise RuntimeError, "adapter crashed" }
    replacement = ->(**) { scheduled }
    attributes = {
      cart: { product.id => 1 }, email: "queue@example.com", user: nil,
      legal_assent: "1", ip: "192.0.2.6", user_agent: "Queue test",
      checkout_nonce: "durable-replay-nonce"
    }
    first = with_stubbed_singleton_method(Foundation::Storefront::ExpireReservationJob, :set, replacement) do
      Foundation::Storefront::CreateOrder.call(**attributes)
    end
    second = Foundation::Storefront::CreateOrder.call(**attributes)
    assert_equal first.id, second.id
    assert_equal 1, product.reload.inventory_quantity
  end

  test "database checkout throttle independently bounds a session burst" do
    10.times do |index|
      assert Foundation::Storefront::CheckoutThrottle.check!(
        session_nonce: "same-session", ip: "192.0.2.#{index + 1}"
      )
    end
    assert_raises(Foundation::Storefront::CheckoutThrottle::Exceeded) do
      Foundation::Storefront::CheckoutThrottle.check!(session_nonce: "same-session", ip: "192.0.2.250")
    end
  end

  test "database checkout throttle normalizes and independently bounds an IP burst" do
    30.times do |index|
      assert Foundation::Storefront::CheckoutThrottle.check!(
        session_nonce: "unique-session-#{index}",
        ip: index.even? ? "2001:db8::1" : "2001:db8:0:0:0:0:0:1"
      )
    end
    assert_raises(Foundation::Storefront::CheckoutThrottle::Exceeded) do
      Foundation::Storefront::CheckoutThrottle.check!(session_nonce: "unique-session-31", ip: "2001:db8::1")
    end
    assert_raises(Foundation::Storefront::CheckoutThrottle::Exceeded) do
      Foundation::Storefront::CheckoutThrottle.check!(session_nonce: "new", ip: "not-an-ip")
    end
  end

  test "order never infers account ownership from matching email" do
    user = users(:confirmed)
    order = create_storefront_order(email: user.email, user: nil)
    assert_nil order.user_id

    owned = create_storefront_order(email: "ignored@example.com", user: user)
    assert_equal user.id, owned.user_id
    assert_equal user.email, owned.email
  end

  test "legal assent and quantity bounds fail closed" do
    product = create_storefront_product
    base = { cart: { product.id => 1 }, email: "guest@example.com", user: nil, ip: nil, user_agent: nil }
    assert_raises(Foundation::Storefront::CreateOrder::InvalidCart) do
      Foundation::Storefront::CreateOrder.call(**base, legal_assent: "0")
    end
    assert_raises(Foundation::Storefront::CreateOrder::InvalidCart) do
      Foundation::Storefront::CreateOrder.call(**base.merge(cart: { product.id => 11 }), legal_assent: "1")
    end
    assert_equal 20, product.reload.inventory_quantity
  end

  test "oversell is rejected and release is idempotent" do
    product = create_storefront_product(inventory_quantity: 2)
    order = create_storefront_order(product: product, quantity: 2)
    assert_raises(Foundation::Storefront::CreateOrder::Unavailable) { create_storefront_order(product: product, quantity: 1) }

    Foundation::Storefront::ReleaseInventory.call(order)
    Foundation::Storefront::ReleaseInventory.call(order)
    assert_equal 2, product.reload.inventory_quantity
    assert_predicate order.reload, :inventory_released_at?
  end

  test "cart has a bounded number of distinct server-side items" do
    cart = (1..21).index_with { 1 }
    assert_raises(Foundation::Storefront::CreateOrder::InvalidCart) do
      Foundation::Storefront::CreateOrder.call(
        cart: cart, email: "guest@example.com", user: nil, legal_assent: "1", ip: nil, user_agent: nil
      )
    end
  end

  test "receipt capability is purpose bound tamper resistant and expires" do
    order = create_storefront_order
    token = Foundation::Storefront::ReceiptAccess.token_for(order)
    assert Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: token)
    assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: "#{token}x")
    wrong = Rails.application.message_verifier(:foundation_storefront_receipt).generate(
      order.public_reference, purpose: "another-purpose", expires_in: 1.day
    )
    assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: wrong)
    travel 25.hours
    assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: token)
  end

  test "browser return capability cannot be renewed by a delayed checkout replay" do
    order = create_storefront_order
    initial = Foundation::Storefront::ReceiptAccess.return_token_for(order)
    travel_to(order.created_at + 25.hours) do
      replay = Foundation::Storefront::ReceiptAccess.return_token_for(order)
      assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: initial)
      assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: replay)
      assert Foundation::Storefront::ReceiptAccess.allowed?(
        order: order, user: nil, token: Foundation::Storefront::ReceiptAccess.token_for(order)
      )
    end
  end

  test "owner access does not authorize a guest order with the same email" do
    user = users(:confirmed)
    guest_order = create_storefront_order(email: user.email)
    assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: guest_order, user: user, token: nil)

    owned = create_storefront_order(user: user)
    assert Foundation::Storefront::ReceiptAccess.allowed?(order: owned, user: user, token: nil)
  end

  test "disguised image bytes fail despite an image declaration" do
    product = create_storefront_product
    product.image.attach(io: StringIO.new("plain text is not a png"), filename: "fake.png", content_type: "image/png")
    assert_not product.valid?
    assert_includes product.errors[:image], "must be PNG, JPEG, WebP, or GIF"
  end

  test "external images allow only safe public HTTP schemes" do
    product = create_storefront_product(image_url: "javascript:alert(1)")
    flunk "unsafe product unexpectedly saved: #{product.inspect}"
  rescue ActiveRecord::RecordInvalid => error
    assert_includes error.record.errors[:image_url], "must use HTTPS on an allowed external image host"
  end

  test "external image host must be explicitly allowlisted" do
    config = Rails.configuration.x.foundation
    previous = config[:storefront_external_image_hosts]
    config[:storefront_external_image_hosts] = [ "cdn.example.net" ]
    assert_predicate create_storefront_product(image_url: "https://cdn.example.net/product.png"), :valid?
    invalid = Foundation::Storefront::Product.new(
      name: "Other host", slug: "other-host", sku: "OTHER-HOST", description: "",
      price_cents: 100, currency: "USD", active: true, inventory_quantity: 1,
      position: 0, image_url: "https://printer.corp/product.png"
    )
    assert_not invalid.valid?
  ensure
    config[:storefront_external_image_hosts] = previous
  end

  test "external images reject local private loopback and metadata hosts" do
    [
      "http://LOCALHOST/image.png", "https://service.LOCAL/image.png",
      "http://127.0.0.1/a.png", "http://127.1/a.png", "http://[::1]/a.png",
      "http://10.1.2.3/a.png", "http://172.16.2.3/a.png", "http://192.168.1.2/a.png",
      "http://169.254.169.254/latest/meta-data", "http://0.0.0.0/a.png"
    ].each do |url|
      product = Foundation::Storefront::Product.new(
        name: "Unsafe image", slug: "unsafe-#{Digest::SHA256.hexdigest(url).first(12)}",
        sku: "UNSAFE-#{Digest::SHA256.hexdigest(url).first(12)}", description: "",
        price_cents: 100, currency: "USD", active: true, inventory_quantity: 1,
        position: 0, image_url: url
      )
      assert_not product.valid?, url
      assert product.errors[:image_url].any?, url
    end
  end
end

class StorefrontCheckoutConcurrencyTest < ActiveSupport::TestCase
  setup do
    @product = committed { create_storefront_product(inventory_quantity: 2) }
  end

  teardown do
    committed do
      digest = Foundation::Storefront::CreateOrder.checkout_digest(concurrent_nonce)
      Foundation::Storefront::Order.where(checkout_key_digest: digest).find_each(&:destroy!)
      @product.destroy! if @product&.persisted?
    end
  end

  test "concurrent checkout nonce replay creates one order and reserves inventory once" do
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    errors = Queue.new
    scheduled = Object.new
    scheduled.define_singleton_method(:perform_later) { |*| true }

    replacement = ->(**) { scheduled }
    with_stubbed_singleton_method(Foundation::Storefront::ExpireReservationJob, :set, replacement) do
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            results << Foundation::Storefront::CreateOrder.call(**concurrent_attributes)
          rescue StandardError => error
            errors << error
          end
        end
      end
      2.times { ready.pop }
      2.times { start << true }
      threads.each { |thread| assert thread.join(10), "concurrent checkout thread did not finish" }
    end

    flunk errors.pop.full_message unless errors.empty?
    orders = 2.times.map { results.pop }
    assert_equal 1, orders.map(&:id).uniq.size
    assert_equal 1, Foundation::Storefront::Order.where(checkout_key_digest: orders.first.checkout_key_digest).count
    assert_equal 1, @product.reload.inventory_quantity
  end

  private

  def committed(&block)
    result = Queue.new
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { result << [ :ok, block.call ] }
    rescue StandardError => error
      result << [ :error, error ]
    end.join
    status, value = result.pop
    raise value if status == :error

    value
  end

  def concurrent_nonce
    @concurrent_nonce ||= "concurrent-#{SecureRandom.hex(12)}"
  end

  def concurrent_attributes
    {
      cart: { @product.id => 1 }, email: "concurrent@example.com", user: nil,
      legal_assent: "1", ip: "192.0.2.77", user_agent: "Concurrency test",
      checkout_nonce: concurrent_nonce
    }
  end
end
