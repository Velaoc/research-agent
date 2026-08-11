# frozen_string_literal: true

module CrmTestHelper
  PASSWORD = "correct horse battery"

  private

  def create_crm_organization(name:, owner:)
    organization = Organizations::Organization.create!(name: name)
    Organizations::Membership.create!(user: owner, organization: organization, role: "owner")
    organization
  end

  def sign_in_crm(user, organization)
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
    post organizations.switch_organization_path(organization)
  end

  def create_crm_contact(organization, **attributes)
    Foundation::Crm::Contact.create!({
      organization: organization,
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada-#{SecureRandom.hex(4)}@example.com"
    }.merge(attributes))
  end

  def create_crm_company(organization, **attributes)
    Foundation::Crm::Company.create!({
      organization: organization,
      name: "Acme #{SecureRandom.hex(3)}"
    }.merge(attributes))
  end

  def create_crm_lead(organization, **attributes)
    Foundation::Crm::Lead.create!({
      organization: organization,
      name: "Lead #{SecureRandom.hex(3)}",
      status: "new"
    }.merge(attributes))
  end

  def create_crm_opportunity(organization, **attributes)
    pipeline = Foundation::Crm::Pipeline.ensure_default!(organization)
    stage = pipeline.stages.ordered.first
    Foundation::Crm::Opportunity.create!({
      organization: organization,
      pipeline: pipeline,
      pipeline_stage: stage,
      name: "Deal #{SecureRandom.hex(3)}",
      amount_cents: 10_000,
      currency: "USD"
    }.merge(attributes))
  end
end

ActiveSupport::TestCase.include(CrmTestHelper)
ActionDispatch::IntegrationTest.include(CrmTestHelper)
