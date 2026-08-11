require "test_helper"

class RuntimeResponsesTest < ActionDispatch::IntegrationTest
  test "preview noindex wraps normal health and error responses" do
    with_env(
      "VELA_HOLODEX_PREVIEW" => "1",
      "APP_HOST" => "https://daily.holodex.test",
      "SMTP_ADDRESS" => nil
    ) do
      get root_path
      assert_equal "noindex", response.headers["X-Robots-Tag"]

      get rails_health_check_path
      assert_response :success
      assert_equal "noindex", response.headers["X-Robots-Tag"]

      get "/healthcheck"
      assert_response :success
      assert_equal "noindex", response.headers["X-Robots-Tag"]

      get "/this-route-does-not-exist"
      assert_response :not_found
      assert_equal "noindex", response.headers["X-Robots-Tag"]
    end
  end

  test "non-preview responses do not carry preview noindex" do
    get root_path

    assert_nil response.headers["X-Robots-Tag"]
  end

  # foundation:module storefront
  test "hostile request Host never changes generated mail links" do
    host! "attacker.invalid"
    with_env("APP_HOST" => "https://canonical.example") do
      mail = Foundation::Storefront::OrderMailer.receipt(create_storefront_order).message

      assert_match %r{https://canonical\.example/storefront/orders/}, mail.body.encoded
      assert_no_match(/attacker\.invalid/, mail.body.encoded)
    end
  end
  # /foundation:module storefront

  # SPEC M9.2 puts every generated link on the APP_HOST origin, not only the
  # ones a mailer renders. A controller and a mailer must agree even while the
  # request carries a different Host.
  test "APP_HOST is the host of controller-generated and mailer-generated URLs alike" do
    owner = users(:confirmed)
    organization = Organizations::Organization.create!(name: "Runtime Links")
    Organizations::Membership.create!(user: owner, organization: organization, role: "owner")

    host! "attacker.invalid"
    with_env("APP_HOST" => "https://links.canonical.example") do
      post user_session_path, params: { user: { email: owner.email, password: "correct horse battery" } }
      post organizations.switch_organization_path(organization)

      captured = nil
      checkout = lambda do |**arguments|
        captured = arguments
        "https://checkout.stripe.test/session_stub"
      end
      with_stubbed_singleton_method(Foundation::BillingGateway, :checkout_url, checkout) do
        post billing_checkout_path, params: { plan: "pro", interval: "month" }
      end
      # foundation:module storefront
      mail = Foundation::Storefront::OrderMailer.receipt(create_storefront_order).message
      assert_match %r{https://links\.canonical\.example/storefront/orders/}, mail.body.encoded
      assert_no_match(/attacker\.invalid/, mail.body.encoded)
      # /foundation:module storefront

      assert_equal "https://links.canonical.example/billing?checkout=success", captured[:success_url]
      assert_equal "https://links.canonical.example/pricing?interval=month", captured[:cancel_url]
      assert_no_match(/attacker\.invalid/, captured.values.join(" "))
    end
  end
end
