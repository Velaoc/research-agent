# frozen_string_literal: true

module BillingTestHelper
  PASSWORD = "correct horse battery"

  private

  def create_billable_organization(name: "Billing Lab", owner: users(:confirmed))
    organization = Organizations::Organization.create!(name: name)
    Organizations::Membership.create!(user: owner, organization: organization, role: "owner")
    organization
  end

  def sign_in_billable(user, organization)
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
    post organizations.switch_organization_path(organization)
  end

  def create_pay_subscription(organization, processor_plan: "price_pro_monthly", status: "active", **attributes)
    customer = Pay::Stripe::Customer.create!(
      owner: organization,
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(6)}",
      default: true
    )
    Pay::Stripe::Subscription.create!({
      customer: customer,
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(6)}",
      processor_plan: processor_plan,
      status: status,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    }.merge(attributes))
  end
end

ActiveSupport::TestCase.include(BillingTestHelper)
ActionDispatch::IntegrationTest.include(BillingTestHelper)
