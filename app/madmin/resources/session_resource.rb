# frozen_string_literal: true

class SessionResource < Madmin::Resource
  model Session

  attribute :id, form: false
  attribute :user, form: false
  attribute :device_name, :string, form: false, label: "Device"
  attribute :auth_method, form: false
  attribute :auth_provider, form: false
  attribute :ip_address, form: false, label: "Sign-in IP"
  attribute :last_seen_ip, form: false, label: "Last-seen IP"
  attribute :last_seen_at, form: false
  attribute :user_agent, form: false
  attribute :ended_at, form: false
  attribute :ended_reason, form: false
  attribute :created_at, form: false

  scope :live
  scope :ended
  menu label: "Sessions", parent: "Security"

  member_action do |record|
    if record.live?
      button_to "Revoke session", main_app.revoke_madmin_session_path(record), method: :post,
        class: "btn btn-danger", data: { turbo_confirm: "Sign out this device?" }
    end
  end

  def self.display_name(record)
    "#{record.device_name} / #{record.user&.email || record.user_id}"
  end

  def self.default_sort_column = "created_at"
  def self.default_sort_direction = "desc"
end
