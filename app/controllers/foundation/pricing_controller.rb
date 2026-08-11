class Foundation::PricingController < ApplicationController
  INTERVALS = %w[month year].freeze

  def show
    @interval = params[:interval].presence_in(INTERVALS) || "month"
    @plans = PricingPlans.plans
    @organization = current_organization if user_signed_in?
    @billing = Foundation::BillingPresenter.new(
      policy: Foundation::BillingPolicy.new(@organization),
      interval: @interval,
      signed_in: user_signed_in?
    )
  end
end
