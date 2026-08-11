# frozen_string_literal: true

require "test_helper"

class CrmModelsTest < ActiveSupport::TestCase
  setup do
    skip "crm module is not declared in this tree" unless Foundation.module_available?("crm")

    @owner = users(:confirmed)
    @org = create_crm_organization(name: "Model Org", owner: @owner)
    @other = create_crm_organization(name: "Other Org", owner: @owner)
  end

  test "contact requires identity and rejects foreign company" do
    contact = Foundation::Crm::Contact.new(organization: @org)
    refute contact.valid?
    assert_includes contact.errors[:base], "Provide a name or email"

    foreign_company = create_crm_company(@other, name: "Foreign")
    contact = Foundation::Crm::Contact.new(
      organization: @org, first_name: "A", company: foreign_company
    )
    refute contact.valid?
    assert_includes contact.errors[:company], "must belong to the same organization"
  end

  test "pipeline ensure_default is idempotent per organization" do
    first = Foundation::Crm::Pipeline.ensure_default!(@org)
    second = Foundation::Crm::Pipeline.ensure_default!(@org)
    assert_equal first.id, second.id
    assert first.stages.count >= 4
    other_pipeline = Foundation::Crm::Pipeline.ensure_default!(@other)
    refute_equal first.id, other_pipeline.id
  end

  test "opportunity move_to_stage rejects cross-org stage" do
    opportunity = create_crm_opportunity(@org)
    foreign = create_crm_opportunity(@other)

    assert_raises(ArgumentError) do
      opportunity.move_to_stage!(foreign.pipeline_stage, actor: @owner)
    end
  end

  test "lead assign_owner writes activity" do
    lead = create_crm_lead(@org)
    assert_difference -> { Foundation::Crm::Activity.count }, 1 do
      lead.assign_owner!(@owner, actor: @owner)
    end
    assert_equal @owner.id, lead.reload.owner_id
  end

  test "note and task stay inside organization" do
    contact = create_crm_contact(@org)
    note = Foundation::Crm::Note.create!(
      organization: @org, author: @owner, notable: contact, body: "Hello"
    )
    assert_equal @org.id, note.organization_id
    assert Foundation::Crm::Activity.for_trackable(contact).exists?(kind: "note_added")

    task = Foundation::Crm::Task.create!(
      organization: @org, creator: @owner, taskable: contact, title: "Call"
    )
    task.complete!(actor: @owner)
    assert_equal "done", task.reload.status
  end

  test "tag uniqueness is per organization" do
    Foundation::Crm::Tag.create!(organization: @org, name: "vip")
    dup = Foundation::Crm::Tag.new(organization: @org, name: "VIP")
    refute dup.valid?

    other = Foundation::Crm::Tag.new(organization: @other, name: "vip")
    assert other.valid?
  end
end
