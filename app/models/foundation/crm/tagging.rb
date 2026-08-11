# frozen_string_literal: true

module Foundation
  module Crm
    class Tagging < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_taggings"

      TAGGABLE_TYPES = %w[
        Foundation::Crm::Contact
        Foundation::Crm::Company
        Foundation::Crm::Lead
        Foundation::Crm::Opportunity
      ].freeze

      belongs_to :tag, class_name: "Foundation::Crm::Tag", inverse_of: :taggings
      belongs_to :taggable, polymorphic: true

      validates :taggable_type, inclusion: { in: TAGGABLE_TYPES }
      validates :tag_id, uniqueness: { scope: %i[taggable_type taggable_id] }
      validate :associations_in_same_organization

      before_validation :sync_organization_from_tag

      private

      def sync_organization_from_tag
        self.organization_id = tag.organization_id if tag
      end

      def associations_in_same_organization
        if tag.present? && organization_id.present? && tag.organization_id != organization_id
          errors.add(:tag, "must belong to the same organization")
        end
        if taggable.present? && organization_id.present? && taggable.respond_to?(:organization_id) &&
            taggable.organization_id != organization_id
          errors.add(:taggable, "must belong to the same organization")
        end
      end
    end
  end
end
