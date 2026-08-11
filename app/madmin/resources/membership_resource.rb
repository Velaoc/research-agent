# frozen_string_literal: true

class MembershipResource < Madmin::Resource
  model Organizations::Membership

  attribute :id, form: false
  attribute :organization, form: false
  attribute :user, form: false
  attribute :role, form: false
  attribute :invited_by, form: false
  attribute :joined_via, form: false
  attribute :verified_at, form: false
  attribute :created_at, form: false

  menu label: "Memberships", position: 30

  def self.route_namespace = nil
end
