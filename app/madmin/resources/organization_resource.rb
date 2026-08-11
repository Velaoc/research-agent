# frozen_string_literal: true

class OrganizationResource < Madmin::Resource
  model Organizations::Organization

  attribute :id, form: false
  attribute :name, form: false
  attribute :memberships_count, form: false
  attribute :admin_plan_key, :string, form: false, label: "Effective plan"
  attribute :admin_plan_source, :string, form: false, label: "Plan source"
  attribute :memberships, form: false
  attribute :created_at, form: false

  menu label: "Organizations", position: 20

  member_action do |record|
    form_with url: main_app.assign_plan_madmin_organization_path(record), method: :post do
      safe_join([
        select_tag(:plan_key, options_for_select(PricingPlans.plans.map { |plan| [ plan.name, plan.key ] }, record.admin_plan_key)),
        submit_tag("Assign plan", class: "btn btn-secondary")
      ])
    end
  end

  member_action do |record|
    if record.manually_assigned_plan?
      button_to "Remove manual plan", main_app.remove_plan_madmin_organization_path(record), method: :post,
        class: "btn btn-danger", data: { turbo_confirm: "Return this organization to subscription/default plan resolution?" }
    end
  end

  def self.display_name(record)
    record.name
  end

  def self.route_namespace = nil
end
