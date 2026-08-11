# frozen_string_literal: true

class SessionEventResource < Madmin::Resource
  model Sessions::Event

  attribute :id, form: false
  attribute :event, form: false
  attribute :identity, form: false
  attribute :user, :string, form: false
  attribute :device_name, :string, form: false, label: "Device"
  attribute :auth_method, form: false
  attribute :auth_provider, form: false
  attribute :failure_reason, form: false
  attribute :revoked_reason, form: false
  attribute :ip_address, form: false
  attribute :user_agent, form: false
  attribute :session_id, form: false
  attribute :occurred_at, form: false

  scope :logins
  scope :failed_logins
  scope :revocations
  scope :last_24_hours
  menu label: "Login activity", parent: "Security"

  def self.display_name(record)
    "#{record.event} / #{record.identity || record.user&.email || 'unknown'}"
  end

  def self.default_sort_column = "occurred_at"
  def self.default_sort_direction = "desc"
  def self.route_namespace = nil
end
