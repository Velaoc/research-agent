# frozen_string_literal: true

class UserResource < Madmin::Resource
  model User

  attribute :id, form: false
  attribute :email, form: false
  attribute :admin, form: false
  attribute :confirmed_at, form: false
  attribute :locked_at, form: false
  attribute :failed_attempts, form: false
  attribute :organizations, form: false
  attribute :created_at, form: false

  menu label: "Users", position: 10

  member_action do |record|
    if record.access_locked?
      button_to "Unlock account", main_app.unlock_madmin_user_path(record), method: :post, class: "btn btn-secondary"
    elsif record != current_user
      button_to "Lock account", main_app.lock_madmin_user_path(record), method: :post,
        class: "btn btn-danger", data: { turbo_confirm: "Lock this account?" }
    end
  end

  member_action do |record|
    if record.sessions.live.exists?
      button_to "Revoke all sessions", main_app.revoke_all_sessions_madmin_user_path(record), method: :post,
        class: "btn btn-danger", data: { turbo_confirm: "Sign this account out on every device?" }
    end
  end

  def self.display_name(record)
    record.email
  end
end
