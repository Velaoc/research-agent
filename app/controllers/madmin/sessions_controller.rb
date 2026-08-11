# frozen_string_literal: true

module Madmin
  class SessionsController < Madmin::ResourceController
    def revoke
      session_row = Session.find(params[:id])
      foundation_admin_audit_subject(session_row)

      if session_row.live?
        session_row.revoke!(reason: :admin_revoked, by: current_user)
        redirect_to madmin_session_path(session_row), notice: "Session revoked."
      else
        foundation_admin_audit_outcome(:rejected)
        redirect_to madmin_session_path(session_row), alert: "That session has already ended."
      end
    end

    private

    def scoped_resources
      super.includes(:user)
    end
  end
end
