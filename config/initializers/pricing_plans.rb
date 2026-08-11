# frozen_string_literal: true

# PricingPlans is the single source of truth for tiers and entitlements.
# Stripe price IDs are deployment configuration, not secrets. The descriptive
# defaults make local/test behavior deterministic and should be replaced with
# real Price IDs before accepting payments.
PricingPlans.configure do |config|
  plan :free do
    price 0
    description "For individuals and small experiments"
    bullets "One workspace", "Up to 3 team members", "Community support"
    allows :core_workspace
    limits :team_members, to: 3
    metadata prices: { month: 0, year: 0 }, currency: "USD"
    default!
  end

  plan :pro do
    stripe_price month: ENV.fetch("STRIPE_PRO_MONTHLY_PRICE_ID", "price_pro_monthly"),
      year: ENV.fetch("STRIPE_PRO_YEARLY_PRICE_ID", "price_pro_yearly")
    description "For teams shipping a growing product"
    bullets "Unlimited workspaces", "Up to 25 team members", "API access", "Priority support"
    allows :core_workspace, :team_collaboration, :api_access, :priority_support
    limits :team_members, to: 25
    metadata prices: { month: 29_00, year: 290_00 },
      stripe_prices: {
        month: ENV.fetch("STRIPE_PRO_MONTHLY_PRICE_ID", "price_pro_monthly"),
        year: ENV.fetch("STRIPE_PRO_YEARLY_PRICE_ID", "price_pro_yearly")
      },
      currency: "USD"
    highlighted!
  end

  plan :enterprise do
    stripe_price month: ENV.fetch("STRIPE_ENTERPRISE_MONTHLY_PRICE_ID", "price_enterprise_monthly"),
      year: ENV.fetch("STRIPE_ENTERPRISE_YEARLY_PRICE_ID", "price_enterprise_yearly")
    description "For organizations that need advanced controls"
    bullets "Unlimited team members", "API access", "Single sign-on", "Dedicated support"
    allows :core_workspace, :team_collaboration, :api_access, :priority_support, :single_sign_on
    unlimited :team_members
    cta_text "Contact sales"
    cta_url "mailto:#{Rails.configuration.x.foundation[:support_email]}"
    # contact_sales is explicit plan metadata — never infer from price labels.
    # Stripe price IDs remain so operator-created subscriptions still resolve.
    metadata prices: { month: 99_00, year: 990_00 },
      stripe_prices: {
        month: ENV.fetch("STRIPE_ENTERPRISE_MONTHLY_PRICE_ID", "price_enterprise_monthly"),
        year: ENV.fetch("STRIPE_ENTERPRISE_YEARLY_PRICE_ID", "price_enterprise_yearly")
      },
      contact_sales: true,
      currency: "USD"
  end

  config.controller_plan_owner :current_organization
  config.interval_default_for_ui = :month
  config.redirect_on_blocked_limit = "/pricing"
end
