# frozen_string_literal: true

module Foundation
  module Crm
    class Note < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_notes"

      NOTABLE_TYPES = %w[
        Foundation::Crm::Contact
        Foundation::Crm::Company
        Foundation::Crm::Lead
        Foundation::Crm::Opportunity
      ].freeze

      belongs_to :author, class_name: "User"
      belongs_to :notable, polymorphic: true

      def self.notable_model_for(type)
        case type.to_s
        when "Foundation::Crm::Contact" then Contact
        when "Foundation::Crm::Company" then Company
        when "Foundation::Crm::Lead" then Lead
        when "Foundation::Crm::Opportunity" then Opportunity
        end
      end

      validates :body, presence: true, length: { maximum: 20_000 }
      validates :notable_type, inclusion: { in: NOTABLE_TYPES }
      validate :notable_in_same_organization

      before_validation :normalize_fields
      after_create :record_activity

      scope :ordered, -> { order(created_at: :desc, id: :desc) }

      private

      def normalize_fields
        self.body = body.to_s.strip
      end

      def notable_in_same_organization
        return if notable.blank? || organization_id.blank?
        return unless notable.respond_to?(:organization_id)
        return if notable.organization_id == organization_id

        errors.add(:notable, "must belong to the same organization")
      end

      def record_activity
        ActivityRecorder.record!(
          organization: organization,
          actor: author,
          trackable: notable,
          kind: "note_added",
          summary: "Note added",
          metadata: { note_id: id }
        )
      end
    end
  end
end
