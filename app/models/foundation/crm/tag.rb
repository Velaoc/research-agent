# frozen_string_literal: true

module Foundation
  module Crm
    class Tag < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_tags"

      has_many :taggings, class_name: "Foundation::Crm::Tagging", dependent: :destroy, inverse_of: :tag
      has_many :contacts, through: :taggings, source: :taggable, source_type: "Foundation::Crm::Contact"
      has_many :companies, through: :taggings, source: :taggable, source_type: "Foundation::Crm::Company"
      has_many :leads, through: :taggings, source: :taggable, source_type: "Foundation::Crm::Lead"
      has_many :opportunities, through: :taggings, source: :taggable, source_type: "Foundation::Crm::Opportunity"

      validates :name, presence: true, length: { maximum: 60 }, uniqueness: { scope: :organization_id, case_sensitive: false }

      before_validation :normalize_fields

      scope :ordered, -> { order(Arel.sql("lower(name) ASC"), :id) }

      private

      def normalize_fields
        self.name = name.to_s.strip
      end
    end
  end
end
