# frozen_string_literal: true

class InvitationResource < Madmin::Resource
  model Organizations::Invitation

  attribute :id, form: false
  attribute :organization, form: false
  attribute :email, form: false
  attribute :role, form: false
  attribute :invited_by, form: false
  attribute :expires_at, form: false
  attribute :accepted_at, form: false
  attribute :created_at, form: false

  menu label: "Invitations", position: 40

  def self.display_name(record)
    record.email
  end

  def self.route_namespace = nil
end
