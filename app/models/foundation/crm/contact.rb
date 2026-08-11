# frozen_string_literal: true

module Foundation
  module Crm
    class Contact < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_contacts"

      belongs_to :company, class_name: "Foundation::Crm::Company", optional: true, inverse_of: :contacts
      belongs_to :owner, class_name: "User", optional: true

      has_many :leads, class_name: "Foundation::Crm::Lead", dependent: :nullify, inverse_of: :contact
      has_many :opportunities, class_name: "Foundation::Crm::Opportunity", dependent: :nullify, inverse_of: :contact
      has_many :notes, as: :notable, class_name: "Foundation::Crm::Note", dependent: :destroy
      has_many :tasks, as: :taskable, class_name: "Foundation::Crm::Task", dependent: :nullify
      has_many :activities, as: :trackable, class_name: "Foundation::Crm::Activity", dependent: :destroy
      has_many :taggings, as: :taggable, class_name: "Foundation::Crm::Tagging", dependent: :destroy
      has_many :tags, through: :taggings

      validates :first_name, length: { maximum: 100 }
      validates :last_name, length: { maximum: 100 }
      validates :email, length: { maximum: 254 }, allow_blank: true
      validates :phone, length: { maximum: 60 }, allow_blank: true
      validates :title, length: { maximum: 120 }, allow_blank: true
      validate :identity_present
      validate :company_in_same_organization

      before_validation :normalize_fields

      scope :ordered, -> { order(Arel.sql("lower(last_name) ASC"), Arel.sql("lower(first_name) ASC"), :id) }
      scope :owned_by, ->(user) { where(owner_id: user.id) }
      scope :search, ->(query) {
        q = query.to_s.strip
        next all if q.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
        where(
          "first_name ILIKE :q OR last_name ILIKE :q OR coalesce(email, '') ILIKE :q OR coalesce(phone, '') ILIKE :q",
          q: pattern
        )
      }

      def display_name
        full = [ first_name, last_name ].map(&:presence).compact.join(" ")
        full.presence || email.presence || "Contact ##{id}"
      end

      private

      def normalize_fields
        self.first_name = first_name.to_s.strip
        self.last_name = last_name.to_s.strip
        self.email = email.to_s.strip.downcase.presence
        self.phone = phone.to_s.strip.presence
        self.title = title.to_s.strip.presence
      end

      def identity_present
        return if first_name.present? || last_name.present? || email.present?

        errors.add(:base, "Provide a name or email")
      end

      def company_in_same_organization
        return if company.blank? || organization_id.blank?
        return if company.organization_id == organization_id

        errors.add(:company, "must belong to the same organization")
      end
    end
  end
end
