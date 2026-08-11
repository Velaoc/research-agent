# frozen_string_literal: true

require "test_helper"

class Foundation::BillingPresenterTest < ActiveSupport::TestCase
  setup do
    @organization = create_billable_organization(name: "Presenter Lab")
  end

  test "source badges follow plan source without controller branching" do
    free = Foundation::BillingPresenter.new(policy: Foundation::BillingPolicy.new(@organization))
    assert_equal "Free plan", free.source_badge_label
    assert_not free.source_badge_selected?

    create_pay_subscription(@organization)
    sub = Foundation::BillingPresenter.new(policy: Foundation::BillingPolicy.new(@organization.reload))
    assert_equal "Stripe subscription", sub.source_badge_label
    assert_predicate sub, :source_badge_selected?

    @organization.assign_pricing_plan!(:pro)
    manual = Foundation::BillingPresenter.new(policy: Foundation::BillingPolicy.new(@organization.reload))
    assert_equal "Manually assigned", manual.source_badge_label
  end

  test "status badges surface grace and delinquent states" do
    create_pay_subscription(@organization, status: "active", ends_at: 3.days.from_now)
    grace = Foundation::BillingPresenter.new(policy: Foundation::BillingPolicy.new(@organization.reload))
    assert_includes grace.status_badges.map { |badge| badge[:label] }, "Payment grace period"

    @organization.pay_customers.destroy_all
    create_pay_subscription(@organization, status: "past_due")
    delinquent = Foundation::BillingPresenter.new(policy: Foundation::BillingPolicy.new(@organization.reload))
    assert_includes delinquent.status_badges.map { |badge| badge[:label] }, "Payment past due"
  end

  test "enterprise contact sales cta comes from plan metadata and cta fields" do
    presenter = Foundation::BillingPresenter.new(
      policy: Foundation::BillingPolicy.new(@organization),
      signed_in: true
    )
    enterprise = PricingPlans.plans.find { |plan| plan.key == :enterprise }
    cta = presenter.plan_cta(enterprise)

    assert_equal :external, cta[:kind]
    assert_equal "Contact sales", cta[:label]
    assert_match(/\Amailto:/, cta[:url])
    assert_equal "Contact us", presenter.price_amount_label(enterprise)
  end
end
