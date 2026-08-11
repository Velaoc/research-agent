# frozen_string_literal: true

module Foundation
  module Crm
    class Company < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_companies"

      has_many :contacts, class_name: "Foundation::Crm::Contact", dependent: :nullify, inverse_of: :company
      has_many :leads, class_name: "Foundation::Crm::Lead", dependent: :nullify, inverse_of: :company
      has_many :opportunities, class_name: "Foundation::Crm::Opportunity", dependent: :nullify, inverse_of: :company
      has_many :notes, as: :notable, class_name: "Foundation::Crm::Note", dependent: :destroy
      has_many :tasks, as: :taskable, class_name: "Foundation::Crm::Task", dependent: :nullify
      has_many :activities, as: :trackable, class_name: "Foundation::Crm::Activity", dependent: :destroy
      has_many :taggings, as: :taggable, class_name: "Foundation::Crm::Tagging", dependent: :destroy
      has_many :tags, through: :taggings

      validates :name, presence: true, length: { maximum: 200 }
      validates :domain, length: { maximum: 253 }, allow_blank: true
      validates :website, length: { maximum: 500 }, allow_blank: true
      validates :phone, length: { maximum: 60 }, allow_blank: true
      validates :industry, length: { maximum: 120 }, allow_blank: true
      validates :domain, uniqueness: { scope: :organization_id, case_sensitive: false }, allow_blank: true

      before_validation :normalize_fields

      scope :ordered, -> { order(Arel.sql("lower(name) ASC"), :id) }
      scope :search, ->(query) {
        q = query.to_s.strip
        next all if q.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
        where("name ILIKE :q OR coalesce(domain, '') ILIKE :q OR coalesce(industry, '') ILIKE :q", q: pattern)
      }

      def display_name
        name
      end

      private

      def normalize_fields
        self.name = name.to_s.strip
        self.domain = domain.to_s.strip.downcase.presence
        self.website = website.to_s.strip.presence
        self.phone = phone.to_s.strip.presence
        self.industry = industry.to_s.strip.presence
      end
    end
  end
end
