# frozen_string_literal: true

module Madmin
  class UsersController < Madmin::ResourceController
    def lock
      user = find_audited_user
      if user == current_user
        reject_admin_action("You cannot lock the account serving this admin session.")
      elsif user.access_locked?
        reject_admin_action("That account is already locked.")
      else
        user.lock_access!
        redirect_to madmin_user_path(user), notice: "Account locked."
      end
    end

    def unlock
      user = find_audited_user
      if user.access_locked?
        user.unlock_access!
        redirect_to madmin_user_path(user), notice: "Account unlocked."
      else
        reject_admin_action("That account is not locked.")
      end
    end

    def revoke_all_sessions
      user = find_audited_user
      count = user.sessions.live.count
      user.revoke_all_sessions!(by: current_user, reason: :admin_revoked)
      redirect_to madmin_user_path(user), notice: "Revoked #{count} live #{'session'.pluralize(count)}."
    end

    private

    def find_audited_user
      User.find(params[:id]).tap { |user| foundation_admin_audit_subject(user) }
    end

    def reject_admin_action(message)
      foundation_admin_audit_outcome(:rejected)
      redirect_to madmin_user_path(params[:id]), alert: message
    end

    def scoped_resources
      super.includes(:organizations)
    end
  end
end
