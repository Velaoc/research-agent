require "test_helper"

class BillingTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:confirmed)
    @organization = create_billable_organization(owner: @owner)
  end

  test "public pricing renders configured tiers and interval toggle" do
    get pricing_path
    assert_response :success
    assert_select "h2", text: "Free"
    assert_select "h2", text: "Pro"
    assert_select "h2", text: "Enterprise"
    assert_select "a[aria-current=page]", text: "Monthly"
    assert_select "p", text: /\$29/
    assert_select "a", text: "Contact sales"

    get pricing_path(interval: "year")
    assert_response :success
    assert_select "a[aria-current=page]", text: "Yearly"
    assert_select "p", text: /\$290/
  end

  test "self-serve free org billing page renders free badge and compare plans" do
    sign_in_billable(@owner, @organization)

    get billing_path
    assert_response :success
    assert_select "h2", text: "Free"
    assert_select "span", text: "Free plan"
    assert_select "a", text: "Compare plans"
    assert_select "form[action=?]", billing_portal_path, count: 0
    assert_select "span", text: "Payment grace period", count: 0
    assert_select "span", text: "Payment past due", count: 0
  end

  test "manual plans are marked and hide self-serve upgrade calls to action" do
    @organization.assign_pricing_plan!(:pro)
    sign_in_billable(@owner, @organization)

    get pricing_path
    assert_response :success
    assert_select "strong", text: "Manually assigned plan."
    assert_select "form[action=?]", billing_checkout_path, count: 0
    assert_select "span", text: /Current plan · manual/
  end

  test "grace subscription renders payment grace badge on billing" do
    create_pay_subscription(@organization, status: "active", ends_at: 5.days.from_now)
    sign_in_billable(@owner, @organization)

    get billing_path
    assert_response :success
    assert_select "span", text: "Stripe subscription"
    assert_select "span", text: "Payment grace period"
    assert_select "form[action=?]", billing_portal_path
  end

  test "delinquent subscription renders payment past due badge on billing" do
    create_pay_subscription(@organization, status: "past_due")
    sign_in_billable(@owner, @organization)

    get billing_path
    assert_response :success
    assert_select "span", text: "Payment past due"
    assert_select "form[action=?]", billing_portal_path
  end

  test "contact sales plan renders sales cta and rejects checkout" do
    sign_in_billable(@owner, @organization)

    get pricing_path
    assert_response :success
    assert_select "a[href=?]", "mailto:#{Rails.configuration.x.foundation[:support_email]}", text: "Contact sales"
    assert_select "form[action=?]", billing_checkout_path do
      assert_select "input[name=plan][value=enterprise]", count: 0
    end

    post billing_checkout_path, params: { plan: "enterprise", interval: "month" }
    assert_redirected_to pricing_path
    assert_match(/sales/i, flash[:alert])
  end

  test "checkout uses the selected configured Stripe price" do
    host! "attacker.invalid"
    sign_in_billable(@owner, @organization)
    captured = nil
    checkout = lambda do |**arguments|
      captured = arguments
      "https://checkout.stripe.test/session_stub"
    end

    with_stubbed_singleton_method(Foundation::BillingGateway, :checkout_url, checkout) do
      post billing_checkout_path, params: { plan: "pro", interval: "year" }
    end

    assert_response :see_other
    assert_redirected_to "https://checkout.stripe.test/session_stub"
    assert_equal @organization, captured[:organization]
    assert_equal "price_pro_yearly", captured[:price_id]
    assert_equal "https://example.com/billing?checkout=success", captured[:success_url]
    assert_equal "https://example.com/pricing?interval=year", captured[:cancel_url]
    assert_no_match(/attacker\.invalid/, captured.values.join(" "))
  end

  test "checkout rejects free, unknown, and manually controlled plans" do
    sign_in_billable(@owner, @organization)

    post billing_checkout_path, params: { plan: "free", interval: "month" }
    assert_redirected_to pricing_path

    @organization.assign_pricing_plan!(:enterprise)
    post billing_checkout_path, params: { plan: "pro", interval: "month" }
    assert_redirected_to pricing_path
    assert_match(/manually assigned/, flash[:alert])
  end

  test "a member cannot start checkout" do
    member = User.create!(
      email: "billing-member@example.com",
      password: PASSWORD,
      legal_assent: "1",
      confirmed_at: Time.current
    )
    Organizations::Membership.create!(user: member, organization: @organization, role: "member")
    sign_in_billable(member, @organization)

    post billing_checkout_path, params: { plan: "pro", interval: "month" }
    assert_redirected_to billing_path
    assert_match(/owners and admins/, flash[:alert])
  end

  test "mixed manual and subscription state still exposes the portal" do
    create_pay_subscription(@organization)
    @organization.assign_pricing_plan!(:enterprise)
    sign_in_billable(@owner, @organization)

    get billing_path
    assert_response :success
    assert_select "span", text: "Manually assigned"
    assert_select "form[action=?]", billing_portal_path
    assert_select "a", text: "Compare plans", count: 0

    portal_arguments = nil
    portal = lambda do |**arguments|
      portal_arguments = arguments
      "https://billing.stripe.test/portal_stub"
    end
    grant_reauthentication!
    with_stubbed_singleton_method(Foundation::BillingGateway, :portal_url, portal) do
      post billing_portal_path
    end
    assert_response :see_other
    assert_redirected_to "https://billing.stripe.test/portal_stub"
    assert_equal @organization, portal_arguments[:organization]
    assert_equal "https://example.com/billing", portal_arguments[:return_url]
  end
end
