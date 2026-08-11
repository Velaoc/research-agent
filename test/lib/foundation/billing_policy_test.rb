# frozen_string_literal: true

require "test_helper"

class Foundation::BillingPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = create_billable_organization(name: "Policy Lab")
    @policy = Foundation::BillingPolicy.new(@organization)
  end

  test "self-serve free plan defaults" do
    assert_predicate @policy, :self_serve?
    assert_predicate @policy, :plan_changeable_in_app?
    assert_not @policy.manually_assigned?
    assert_not @policy.grace?
    assert_not @policy.delinquent?
    assert_predicate @policy, :allow_checkout?
    assert_equal :default, @policy.source
  end

  test "manual assignment is not self-serve" do
    @organization.assign_pricing_plan!(:enterprise)
    policy = Foundation::BillingPolicy.new(@organization.reload)

    assert_predicate policy, :manually_assigned?
    assert_not policy.self_serve?
    assert_not policy.plan_changeable_in_app?
    assert_not policy.allow_checkout?
    assert_not policy.show_self_serve_plan_ctas?
  end

  test "grace uses pay subscription on_grace_period" do
    create_pay_subscription(@organization, status: "active", ends_at: 1.week.from_now)
    policy = Foundation::BillingPolicy.new(@organization.reload)

    assert_predicate policy, :grace?
    assert_not policy.delinquent?
  end

  test "delinquent covers past_due and unpaid" do
    create_pay_subscription(@organization, status: "past_due")
    assert_predicate Foundation::BillingPolicy.new(@organization.reload), :delinquent?

    @organization.pay_customers.destroy_all
    create_pay_subscription(@organization, status: "unpaid")
    assert_predicate Foundation::BillingPolicy.new(@organization.reload), :delinquent?
  end

  test "contact_sales reads explicit plan metadata" do
    enterprise = PricingPlans.plans.find { |plan| plan.key == :enterprise }
    pro = PricingPlans.plans.find { |plan| plan.key == :pro }

    assert Foundation::BillingPolicy.contact_sales_plan?(enterprise)
    assert_not Foundation::BillingPolicy.contact_sales_plan?(pro)
  end
end
