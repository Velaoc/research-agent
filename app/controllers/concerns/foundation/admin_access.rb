# frozen_string_literal: true

module Foundation
  module AdminAccess
    extend ActiveSupport::Concern

    included do
      before_action :require_foundation_admin!
      around_action :audit_foundation_admin_mutation
    end

    private

    def require_foundation_admin!
      head :not_found unless current_user&.admin?
    end

    def foundation_admin_audit_subject(record)
      @foundation_admin_audit_subject = {
        type: record.class.base_class.name,
        id: record.id
      }
    end

    def foundation_admin_audit_bulk_subject(type)
      @foundation_admin_audit_subject = { type: type.to_s, id: nil }
    end

    def foundation_admin_audit_outcome(outcome)
      @foundation_admin_audit_outcome = outcome.to_s
    end

    def foundation_admin_audit_details(details)
      @foundation_admin_audit_details = details.slice(:created, :updated, :errors)
    end

    def audit_foundation_admin_mutation
      return yield if request.get? || request.head?

      error_class = nil
      yield
    rescue StandardError => error
      error_class = error.class.name
      raise
    ensure
      if request && !request.get? && !request.head?
        Foundation::Admin::Audit.write(
          action: "#{controller_path}##{action_name}",
          actor: current_user,
          request: request,
          subject: foundation_admin_audit_subject_from_request,
          outcome: @foundation_admin_audit_outcome || inferred_foundation_admin_audit_outcome(error_class),
          error_class: error_class,
          details: @foundation_admin_audit_details
        )
      end
    end

    def foundation_admin_audit_subject_from_request
      @foundation_admin_audit_subject || {
        type: request.path_parameters[:controller].to_s,
        id: request.path_parameters[:id]
      }
    end

    def inferred_foundation_admin_audit_outcome(error_class)
      return "failed" if error_class
      return "rejected" if response.client_error? || response.server_error?

      "succeeded"
    end
  end
end
