require "test_helper"

class BillableOrganizationTest < ActiveSupport::TestCase
  setup do
    @organization = Organizations::Organization.create!(name: "Plan Lab")
    Organizations::Membership.create!(
      organization: @organization,
      user: users(:confirmed),
      role: "owner"
    )
  end

  test "plan resolution precedence is manual then subscription then free" do
    assert_equal :free, @organization.current_pricing_plan.key
    assert_equal :default, @organization.current_pricing_plan_source

    subscription = create_subscription(processor_plan: "price_pro_monthly")
    assert_equal :pro, @organization.reload.current_pricing_plan.key
    assert_equal :subscription, @organization.current_pricing_plan_source

    @organization.assign_pricing_plan!(:enterprise)
    assert_equal :enterprise, @organization.reload.current_pricing_plan.key
    assert_equal :assignment, @organization.current_pricing_plan_source
    assert_equal subscription, @organization.current_pricing_plan_resolution.subscription

    @organization.remove_pricing_plan!
    assert_equal :pro, @organization.reload.current_pricing_plan.key
  end

  test "entitlement helpers query the effective plan" do
    assert @organization.plan_allows?(:core_workspace)
    assert_not @organization.plan_allows?(:api_access)
    assert_not @organization.plan_allows?(:single_sign_on)

    @organization.assign_pricing_plan!(:pro)
    assert @organization.plan_allows?(:api_access)
    assert @organization.plan_allows?(:priority_support)
    assert_not @organization.plan_allows?(:single_sign_on)

    @organization.assign_pricing_plan!(:enterprise)
    assert @organization.plan_allows?(:single_sign_on)
  end

  test "manual assignment hides upgrade CTAs without hiding live billing management" do
    create_subscription(processor_plan: "price_pro_yearly")
    @organization.assign_pricing_plan!(:enterprise)

    assert_predicate @organization, :manually_assigned_plan?
    assert_not @organization.show_self_serve_plan_ctas?
    assert_predicate @organization, :billing_management_available?
  end

  test "organization updates use the organization-aware Pay sync predicate" do
    create_subscription(processor_plan: "price_pro_monthly")

    assert_nothing_raised { @organization.update!(name: "Renamed Plan Lab") }
    assert_equal "Renamed Plan Lab", @organization.reload.name
  end

  test "a Stripe webhook sync changes subscription-derived plan without a network call" do
    subscription = create_subscription(processor_plan: "price_pro_monthly")
    webhook = Pay::Webhook.create!(
      processor: "stripe",
      event_type: "customer.subscription.updated",
      event: {
        id: "evt_plan_change",
        type: "customer.subscription.updated",
        data: { object: { id: subscription.processor_id } }
      }
    )

    sync = lambda do |_processor_id, **_options|
      subscription.update!(processor_plan: "price_enterprise_yearly", status: "active")
      subscription
    end

    with_stubbed_singleton_method(Pay::Stripe::Subscription, :sync, sync) do
      Pay::Webhooks::ProcessJob.perform_now(webhook)
    end

    assert_equal :enterprise, @organization.reload.current_pricing_plan.key
    assert_equal :subscription, @organization.current_pricing_plan_source
  end

  private

  def create_subscription(processor_plan:)
    create_pay_subscription(@organization, processor_plan: processor_plan)
  end
end
