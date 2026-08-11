# frozen_string_literal: true

module Foundation
  # Organization-facing billing decisions for controllers and presenters.
  # Wraps the billable organization rather than growing BillableOrganization:
  # that concern owns Pay/PricingPlans integration; this object answers
  # product policy questions without competing model APIs.
  class BillingPolicy
    DELINQUENT_STATUSES = %w[past_due unpaid].freeze

    attr_reader :organization

    def initialize(organization = nil)
      @organization = organization
    end

    def plan
      organization&.current_pricing_plan
    end

    def source
      organization&.current_pricing_plan_source || :default
    end

    def manually_assigned?
      organization&.manually_assigned_plan? || false
    end

    def self_serve?
      !manually_assigned?
    end

    def plan_changeable_in_app?
      self_serve?
    end

    def billing_management_available?
      organization&.billing_management_available? || false
    end

    def show_self_serve_plan_ctas?
      return true unless organization

      organization.show_self_serve_plan_ctas?
    end

    def live_subscription
      organization&.live_subscription
    end

    def grace?
      subscription = live_subscription
      subscription.present? && subscription.on_grace_period?
    end

    def delinquent?
      subscription = live_subscription
      subscription.present? && DELINQUENT_STATUSES.include?(subscription.status.to_s)
    end

    def allow_checkout?
      organization.present? && self_serve? && !billing_management_available?
    end

    def self.contact_sales_plan?(plan)
      plan&.metadata&.[](:contact_sales) == true
    end

    def contact_sales_plan?(plan = self.plan)
      self.class.contact_sales_plan?(plan)
    end
  end
end
