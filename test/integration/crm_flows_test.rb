# frozen_string_literal: true

require "test_helper"

class CrmFlowsTest < ActionDispatch::IntegrationTest
  setup do
    skip "crm module is not declared in this tree" unless Foundation.module_available?("crm")

    @user = users(:confirmed)
    @org = create_crm_organization(name: "Flow Org", owner: @user)
    sign_in_crm(@user, @org)
  end

  test "overview and primary CRUD surfaces render" do
    get crm_root_path
    assert_response :success
    assert_select "h1", text: "CRM"

    get crm_contacts_path
    assert_response :success
    get new_crm_contact_path
    assert_response :success

    get crm_companies_path
    assert_response :success
    get crm_leads_path
    assert_response :success
    get crm_opportunities_path
    assert_response :success
    get crm_pipelines_path
    assert_response :success
    get crm_tasks_path
    assert_response :success
    get crm_tags_path
    assert_response :success
  end

  test "contact create show note task and filters" do
    post crm_contacts_path, params: {
      contact: { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", owner_id: @user.id }
    }
    contact = Foundation::Crm::Contact.for_organization(@org).order(:id).last
    assert_redirected_to crm_contact_path(contact)
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Grace Hopper"

    assert_difference -> { Foundation::Crm::Note.for_organization(@org).count }, 1 do
      post crm_notes_path, params: {
        notable_type: "Foundation::Crm::Contact",
        notable_id: contact.id,
        note: { body: "Called about licensing." }
      }
    end
    assert_redirected_to crm_contact_path(contact)

    assert_difference -> { Foundation::Crm::Task.for_organization(@org).count }, 1 do
      post crm_tasks_path, params: {
        task: {
          title: "Send proposal",
          assignee_id: @user.id,
          taskable_type: "Foundation::Crm::Contact",
          taskable_id: contact.id
        }
      }
    end

    get crm_contacts_path, params: { q: "Grace", mine: "1" }
    assert_response :success
    assert_includes response.body, "Grace Hopper"
  end

  test "lead assignment records activity" do
    lead = create_crm_lead(@org, name: "Inbound lead")
    post assign_crm_lead_path(lead), params: { owner_id: @user.id }
    assert_redirected_to crm_lead_path(lead)
    assert_equal @user.id, lead.reload.owner_id
    assert Foundation::Crm::Activity.for_organization(@org).for_trackable(lead).exists?(kind: "assigned")
  end

  test "opportunity stage movement updates status and timeline" do
    opportunity = create_crm_opportunity(@org, name: "Big deal", amount_cents: 50_000)
    won_stage = opportunity.pipeline.stages.find_by!(closed_won: true)

    post move_stage_crm_opportunity_path(opportunity), params: { pipeline_stage_id: won_stage.id }
    assert_redirected_to crm_opportunity_path(opportunity)
    opportunity.reload
    assert_equal won_stage.id, opportunity.pipeline_stage_id
    assert_equal "won", opportunity.status
    assert Foundation::Crm::Activity.for_organization(@org).for_trackable(opportunity).exists?(kind: "stage_changed")
  end

  test "task completion marks done" do
    task = Foundation::Crm::Task.create!(
      organization: @org, creator: @user, assignee: @user, title: "Follow up"
    )
    post complete_crm_task_path(task)
    assert_response :redirect
    assert_equal "done", task.reload.status
    assert task.completed_at.present?
  end

  test "tag create and default pipeline ensure" do
    post crm_tags_path, params: { tag: { name: "priority" } }
    assert_redirected_to crm_tags_path
    assert Foundation::Crm::Tag.for_organization(@org).exists?(name: "priority")

    get crm_opportunities_path
    assert_response :success
    assert Foundation::Crm::Pipeline.for_organization(@org).exists?
  end

  test "guests are sent to sign in" do
    delete destroy_user_session_path
    get crm_root_path
    assert_redirected_to new_user_session_path
  end
end
