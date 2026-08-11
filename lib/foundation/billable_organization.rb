# frozen_string_literal: true

module Foundation
  module BillableOrganization
    extend ActiveSupport::Concern

    BILLABLE_SUBSCRIPTION_STATUSES = %w[active trialing past_due unpaid].freeze

    included do
      pay_customer stripe_attributes: :stripe_customer_attributes
      include PricingPlans::PlanOwner
    end

    # Payment processors require an email. Organization billing follows the
    # durable owner role rather than whichever member happens to open checkout.
    def email
      memberships.includes(:user).find_by(role: "owner")&.user&.email
    end

    def pay_customer_name
      name
    end

    # Pay's stock predicate watches a persisted email column. Organizations
    # expose their owner's email as a method instead, so synchronize on the
    # organization's own persisted customer-facing attribute.
    def pay_should_sync_customer?
      saved_change_to_name?
    end

    def stripe_customer_attributes(pay_customer)
      { metadata: { organization_id: pay_customer.owner_id } }
    end

    def manually_assigned_plan?
      current_pricing_plan_source == :assignment
    end

    def show_self_serve_plan_ctas?
      !manually_assigned_plan?
    end

    # Billing management is independent from entitlement resolution. A manual
    # override may coexist with a live subscription, which must remain
    # manageable so the customer can cancel or change its payment method.
    def live_subscription
      Pay::Subscription
        .where(customer_id: Pay::Customer.where(owner: self).select(:id))
        .where(status: BILLABLE_SUBSCRIPTION_STATUSES)
        .order(created_at: :desc)
        .first
    end

    def billing_management_available?
      live_subscription.present?
    end

    # Read-only projections for the admin resource. Mutations continue to go
    # through pricing_plans' assign/remove APIs rather than writable fields.
    def admin_plan_key
      current_pricing_plan.key.to_s
    end

    def admin_plan_source
      current_pricing_plan_source.to_s
    end
  end
end
