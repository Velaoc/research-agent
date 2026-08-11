class Foundation::BillingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_organization
  before_action :set_billing_policy
  before_action :require_billing_manager!, only: %i[checkout portal]
  before_action :require_recent_reauthentication!, only: :portal

  def show
    @billing = Foundation::BillingPresenter.new(policy: @billing_policy, signed_in: true)
  end

  def checkout
    if @billing_policy.manually_assigned?
      return redirect_to(pricing_path, alert: "Self-serve upgrades are unavailable for manually assigned plans.")
    end
    if @billing_policy.billing_management_available?
      return redirect_to(billing_path, alert: "Manage the existing subscription in the billing portal.")
    end

    plan = PricingPlans.plans.find { |candidate| candidate.key.to_s == params[:plan] }
    if Foundation::BillingPolicy.contact_sales_plan?(plan)
      return redirect_to(pricing_path, alert: "This plan is sold through sales. Contact sales to continue.")
    end

    interval = params[:interval].presence_in(%w[month year])
    price_id = plan&.metadata&.dig(:stripe_prices, interval&.to_sym)
    return redirect_to(pricing_path, alert: "Choose an available paid plan and billing interval.") if price_id.blank?

    url = Foundation::BillingGateway.checkout_url(
      organization: @organization,
      price_id: price_id,
      success_url: billing_url(checkout: "success"),
      cancel_url: pricing_url(interval: interval)
    )
    redirect_to url, allow_other_host: true, status: :see_other
  end

  def portal
    unless @billing_policy.billing_management_available?
      return redirect_to billing_path, alert: "There is no active subscription to manage."
    end

    url = Foundation::BillingGateway.portal_url(
      organization: @organization,
      return_url: billing_url
    )
    redirect_to url, allow_other_host: true, status: :see_other
  end

  private

  def set_organization
    @organization = current_organization
    redirect_to(organizations.organizations_path, alert: "Choose an organization first.") unless @organization
  end

  def set_billing_policy
    return unless @organization

    @billing_policy = Foundation::BillingPolicy.new(@organization)
  end

  def require_billing_manager!
    return if current_user.role_in(@organization).in?(%i[owner admin])

    redirect_to billing_path, alert: "Only organization owners and admins can manage billing."
  end
end
