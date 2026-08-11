# frozen_string_literal: true

module Foundation
  module Crm
    class Lead < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_leads"

      STATUSES = %w[new contacted qualified disqualified converted].freeze

      belongs_to :company, class_name: "Foundation::Crm::Company", optional: true, inverse_of: :leads
      belongs_to :contact, class_name: "Foundation::Crm::Contact", optional: true, inverse_of: :leads
      belongs_to :owner, class_name: "User", optional: true

      has_many :notes, as: :notable, class_name: "Foundation::Crm::Note", dependent: :destroy
      has_many :tasks, as: :taskable, class_name: "Foundation::Crm::Task", dependent: :nullify
      has_many :activities, as: :trackable, class_name: "Foundation::Crm::Activity", dependent: :destroy
      has_many :taggings, as: :taggable, class_name: "Foundation::Crm::Tagging", dependent: :destroy
      has_many :tags, through: :taggings

      validates :name, presence: true, length: { maximum: 200 }
      validates :email, length: { maximum: 254 }, allow_blank: true
      validates :phone, length: { maximum: 60 }, allow_blank: true
      validates :source, length: { maximum: 120 }, allow_blank: true
      validates :status, inclusion: { in: STATUSES }
      validates :description, length: { maximum: 10_000 }
      validate :associations_in_same_organization

      before_validation :normalize_fields

      scope :ordered, -> { order(created_at: :desc, id: :desc) }
      scope :owned_by, ->(user) { where(owner_id: user.id) }
      scope :with_status, ->(status) {
        status.to_s.presence_in(STATUSES) ? where(status: status) : all
      }
      scope :search, ->(query) {
        q = query.to_s.strip
        next all if q.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
        where("name ILIKE :q OR coalesce(email, '') ILIKE :q OR coalesce(source, '') ILIKE :q", q: pattern)
      }

      def display_name
        name
      end

      def assign_owner!(user, actor:)
        previous = owner_id
        update!(owner: user)
        ActivityRecorder.record!(
          organization: organization,
          actor: actor,
          trackable: self,
          kind: "assigned",
          summary: user ? "Assigned to #{user.email}" : "Unassigned",
          metadata: { previous_owner_id: previous, owner_id: owner_id }
        )
      end

      def advance_status!(new_status, actor:)
        raise ArgumentError, "invalid status" unless new_status.to_s.presence_in(STATUSES)

        previous = status
        update!(status: new_status)
        ActivityRecorder.record!(
          organization: organization,
          actor: actor,
          trackable: self,
          kind: "status_changed",
          summary: "Status changed from #{previous} to #{new_status}",
          metadata: { from: previous, to: new_status }
        )
      end

      private

      def normalize_fields
        self.name = name.to_s.strip
        self.email = email.to_s.strip.downcase.presence
        self.phone = phone.to_s.strip.presence
        self.source = source.to_s.strip.presence
        self.status = "new" if status.blank?
        self.description = description.to_s
      end

      def associations_in_same_organization
        if company.present? && organization_id.present? && company.organization_id != organization_id
          errors.add(:company, "must belong to the same organization")
        end
        if contact.present? && organization_id.present? && contact.organization_id != organization_id
          errors.add(:contact, "must belong to the same organization")
        end
      end
    end
  end
end
