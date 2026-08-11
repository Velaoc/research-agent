# frozen_string_literal: true

module Madmin
  class OrganizationsController < Madmin::ResourceController
    before_action :require_recent_reauthentication!, only: %i[assign_plan remove_plan]

    def assign_plan
      organization = find_audited_organization
      plan = PricingPlans.plans.find { |candidate| candidate.key.to_s == params[:plan_key].to_s }

      if plan
        organization.assign_pricing_plan!(plan.key)
        redirect_to madmin_organization_path(organization), notice: "Assigned the #{plan.name} plan."
      else
        foundation_admin_audit_outcome(:rejected)
        redirect_to madmin_organization_path(organization), alert: "Choose a configured plan."
      end
    end

    def remove_plan
      organization = find_audited_organization
      if organization.manually_assigned_plan?
        organization.remove_pricing_plan!
        redirect_to madmin_organization_path(organization), notice: "Removed the manual plan assignment."
      else
        foundation_admin_audit_outcome(:rejected)
        redirect_to madmin_organization_path(organization), alert: "That organization has no manual plan assignment."
      end
    end

    private

    def find_audited_organization
      Organizations::Organization.find(params[:id]).tap do |organization|
        foundation_admin_audit_subject(organization)
      end
    end

    def scoped_resources
      super.includes(memberships: :user)
    end
  end
end
