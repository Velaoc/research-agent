# frozen_string_literal: true

module Foundation
  # Labels, badges, and call-to-action choices for billing and pricing pages.
  # Controllers and views branch on these presentation answers, never on plan
  # source symbols directly.
  class BillingPresenter
    SOURCE_BADGES = {
      assignment: { label: "Manually assigned", selected: true },
      subscription: { label: "Stripe subscription", selected: true },
      default: { label: "Free plan", selected: false }
    }.freeze

    attr_reader :policy, :interval, :signed_in

    def initialize(policy:, interval: "month", signed_in: false)
      @policy = policy
      @interval = interval.to_s
      @signed_in = signed_in
    end

    def organization
      policy.organization
    end

    def plan
      policy.plan
    end

    def plan_name
      plan.name
    end

    def source_badge
      SOURCE_BADGES.fetch(policy.source) { SOURCE_BADGES[:default] }
    end

    def source_badge_label
      source_badge[:label]
    end

    def source_badge_selected?
      source_badge[:selected]
    end

    def status_badges
      badges = []
      badges << { label: "Payment grace period", selected: true } if policy.grace?
      badges << { label: "Payment past due", selected: true } if policy.delinquent?
      badges
    end

    def show_manage_subscription?
      policy.billing_management_available?
    end

    def show_compare_plans?
      policy.show_self_serve_plan_ctas?
    end

    def mixed_assignment_notice
      return unless policy.manually_assigned? && policy.billing_management_available?

      "Your administrator controls feature access. The billing portal remains available for the separate live subscription."
    end

    def manual_plan_banner?
      organization.present? && policy.manually_assigned?
    end

    def current_plan?(candidate)
      organization && candidate == plan
    end

    def price_cents_for(candidate)
      candidate.metadata.dig(:prices, interval.to_sym).to_i
    end

    def free_price?(candidate)
      price_cents_for(candidate).zero? && !policy.contact_sales_plan?(candidate)
    end

    def price_amount_label(candidate)
      return "Contact us" if policy.contact_sales_plan?(candidate)

      cents = price_cents_for(candidate)
      return "Free" if cents.zero?

      format("$%d", cents / 100)
    end

    def show_interval_suffix?(candidate)
      !free_price?(candidate) && !policy.contact_sales_plan?(candidate)
    end

    def plan_cta(candidate)
      if current_plan?(candidate)
        {
          kind: :badge,
          label: policy.manually_assigned? ? "Current plan · manual" : "Current plan",
          selected: true
        }
      elsif organization && policy.manually_assigned?
        { kind: :badge, label: "Administrator managed", selected: false }
      elsif policy.contact_sales_plan?(candidate)
        contact_sales_cta(candidate)
      elsif free_price?(candidate)
        {
          kind: :link,
          label: "Get started",
          path: signed_in ? :billing : :registration,
          style: "md-button md-button--outlined"
        }
      elsif signed_in
        {
          kind: :checkout,
          label: "Choose #{candidate.name}",
          plan_key: candidate.key,
          interval: interval,
          style: "md-button md-button--filled"
        }
      else
        {
          kind: :link,
          label: "Sign in to subscribe",
          path: :session,
          style: "md-button md-button--filled"
        }
      end
    end

    private

    def contact_sales_cta(candidate)
      url = candidate.cta_url.presence ||
        "mailto:#{Rails.configuration.x.foundation[:support_email]}"
      {
        kind: :external,
        label: candidate.cta_text.presence || "Contact sales",
        url: url,
        style: "md-button md-button--filled"
      }
    end
  end
end
