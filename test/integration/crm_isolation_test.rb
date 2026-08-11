# frozen_string_literal: true

require "test_helper"

# Organization isolation is a security property of the CRM module.
# A member of org A must never read or mutate org B's records; probing a
# foreign id must be indistinguishable from probing a nonexistent one.
class CrmIsolationTest < ActionDispatch::IntegrationTest
  setup do
    skip "crm module is not declared in this tree" unless Foundation.module_available?("crm")

    @user_a = users(:confirmed)
    @user_b = User.create!(
      email: "crm-b-#{SecureRandom.hex(4)}@example.com",
      password: PASSWORD,
      legal_assent: "1",
      confirmed_at: Time.current
    )

    @org_a = create_crm_organization(name: "Org Alpha", owner: @user_a)
    @org_b = create_crm_organization(name: "Org Beta", owner: @user_b)

    @contact_a = create_crm_contact(@org_a, first_name: "Alpha", last_name: "Contact", owner: @user_a)
    @contact_b = create_crm_contact(@org_b, first_name: "Beta", last_name: "Contact", owner: @user_b)
    @company_a = create_crm_company(@org_a, name: "Alpha Co")
    @company_b = create_crm_company(@org_b, name: "Beta Co")
    @lead_a = create_crm_lead(@org_a, name: "Alpha Lead", owner: @user_a)
    @lead_b = create_crm_lead(@org_b, name: "Beta Lead", owner: @user_b)
    @opportunity_a = create_crm_opportunity(@org_a, name: "Alpha Deal", owner: @user_a)
    @opportunity_b = create_crm_opportunity(@org_b, name: "Beta Deal", owner: @user_b)
    @task_a = Foundation::Crm::Task.create!(
      organization: @org_a, creator: @user_a, assignee: @user_a, title: "Alpha task"
    )
    @task_b = Foundation::Crm::Task.create!(
      organization: @org_b, creator: @user_b, assignee: @user_b, title: "Beta task"
    )
    @note_b = Foundation::Crm::Note.create!(
      organization: @org_b, author: @user_b, notable: @contact_b, body: "Secret note"
    )
    @tag_b = Foundation::Crm::Tag.create!(organization: @org_b, name: "beta-only")
    @pipeline_b = Foundation::Crm::Pipeline.for_organization(@org_b).first
  end

  test "index listings never include another organization's records" do
    sign_in_crm(@user_a, @org_a)

    get crm_contacts_path
    assert_response :success
    assert_includes response.body, "Alpha Contact"
    refute_includes response.body, "Beta Contact"

    get crm_companies_path
    assert_response :success
    assert_includes response.body, "Alpha Co"
    refute_includes response.body, "Beta Co"

    get crm_leads_path
    assert_response :success
    assert_includes response.body, "Alpha Lead"
    refute_includes response.body, "Beta Lead"

    get crm_opportunities_path
    assert_response :success
    assert_includes response.body, "Alpha Deal"
    refute_includes response.body, "Beta Deal"

    get crm_tasks_path
    assert_response :success
    assert_includes response.body, "Alpha task"
    refute_includes response.body, "Beta task"
  end

  test "show for another organization's ids is not found" do
    sign_in_crm(@user_a, @org_a)

    get crm_contact_path(@contact_b)
    assert_response :not_found

    get crm_company_path(@company_b)
    assert_response :not_found

    get crm_lead_path(@lead_b)
    assert_response :not_found

    get crm_opportunity_path(@opportunity_b)
    assert_response :not_found

    get crm_task_path(@task_b)
    assert_response :not_found

    get crm_pipeline_path(@pipeline_b)
    assert_response :not_found
  end

  test "update and destroy for another organization's ids are not found" do
    sign_in_crm(@user_a, @org_a)

    patch crm_contact_path(@contact_b), params: { contact: { first_name: "Hijacked" } }
    assert_response :not_found
    assert_equal "Beta", @contact_b.reload.first_name

    delete crm_contact_path(@contact_b)
    assert_response :not_found
    assert Foundation::Crm::Contact.exists?(@contact_b.id)

    patch crm_lead_path(@lead_b), params: { lead: { name: "Hijacked" } }
    assert_response :not_found
    assert_equal "Beta Lead", @lead_b.reload.name

    delete crm_opportunity_path(@opportunity_b)
    assert_response :not_found
    assert Foundation::Crm::Opportunity.exists?(@opportunity_b.id)

    delete crm_task_path(@task_b)
    assert_response :not_found
    assert Foundation::Crm::Task.exists?(@task_b.id)

    delete crm_note_path(@note_b)
    assert_response :not_found
    assert Foundation::Crm::Note.exists?(@note_b.id)

    delete crm_tag_path(@tag_b)
    assert_response :not_found
    assert Foundation::Crm::Tag.exists?(@tag_b.id)
  end

  test "assignment and stage movement reject foreign owners and stages" do
    sign_in_crm(@user_a, @org_a)

    prior_owner_id = @lead_a.owner_id
    post assign_crm_lead_path(@lead_a), params: { owner_id: @user_b.id }
    assert_redirected_to crm_lead_path(@lead_a)
    assert_equal prior_owner_id, @lead_a.reload.owner_id
    refute_equal @user_b.id, @lead_a.owner_id

    prior_stage_id = @opportunity_a.pipeline_stage_id
    foreign_stage = @opportunity_b.pipeline_stage
    post move_stage_crm_opportunity_path(@opportunity_a), params: { pipeline_stage_id: foreign_stage.id }
    assert_redirected_to crm_opportunity_path(@opportunity_a)
    assert_equal prior_stage_id, @opportunity_a.reload.pipeline_stage_id
    refute_equal foreign_stage.id, @opportunity_a.pipeline_stage_id
  end

  test "notes cannot target another organization's records" do
    sign_in_crm(@user_a, @org_a)

    assert_no_difference -> { Foundation::Crm::Note.count } do
      post crm_notes_path, params: {
        notable_type: "Foundation::Crm::Contact",
        notable_id: @contact_b.id,
        note: { body: "Should not land" }
      }
    end
    assert_response :not_found
  end

  test "creating a contact always stamps the current organization" do
    sign_in_crm(@user_a, @org_a)

    assert_difference -> { Foundation::Crm::Contact.for_organization(@org_a).count }, 1 do
      post crm_contacts_path, params: {
        contact: { first_name: "New", last_name: "Person", email: "new-person@example.com" }
      }
    end
    contact = Foundation::Crm::Contact.order(:id).last
    assert_equal @org_a.id, contact.organization_id
    assert_equal 0, Foundation::Crm::Contact.for_organization(@org_b).where(email: "new-person@example.com").count
  end

  test "model scopes never cross organizations even when ids collide conceptually" do
    assert_equal [ @contact_a.id ], Foundation::Crm::Contact.for_organization(@org_a).pluck(:id)
    assert_equal [ @contact_b.id ], Foundation::Crm::Contact.for_organization(@org_b).pluck(:id)
    assert_raises(ActiveRecord::RecordNotFound) do
      Foundation::Crm::Contact.for_organization(@org_a).find(@contact_b.id)
    end
  end
end
