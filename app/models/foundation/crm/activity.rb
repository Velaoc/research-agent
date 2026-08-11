# frozen_string_literal: true

module Foundation
  module Crm
    class Activity < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_activities"

      TRACKABLE_TYPES = %w[
        Foundation::Crm::Contact
        Foundation::Crm::Company
        Foundation::Crm::Lead
        Foundation::Crm::Opportunity
        Foundation::Crm::Task
      ].freeze

      belongs_to :actor, class_name: "User", optional: true
      belongs_to :trackable, polymorphic: true

      validates :kind, presence: true, length: { maximum: 80 }
      validates :summary, presence: true, length: { maximum: 500 }
      validates :trackable_type, inclusion: { in: TRACKABLE_TYPES }
      validate :trackable_in_same_organization

      before_validation :normalize_fields

      scope :ordered, -> { order(created_at: :desc, id: :desc) }
      scope :for_trackable, ->(record) {
        where(trackable_type: record.class.name, trackable_id: record.id)
      }

      private

      def normalize_fields
        self.kind = kind.to_s.strip
        self.summary = summary.to_s.strip
        self.metadata = {} if metadata.nil?
      end

      def trackable_in_same_organization
        return if trackable.blank? || organization_id.blank?
        return unless trackable.respond_to?(:organization_id)
        return if trackable.organization_id == organization_id

        errors.add(:trackable, "must belong to the same organization")
      end
    end
  end
end
