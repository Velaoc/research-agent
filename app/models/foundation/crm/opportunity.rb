# frozen_string_literal: true

module Foundation
  module Crm
    class Opportunity < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_opportunities"

      STATUSES = %w[open won lost].freeze

      belongs_to :pipeline, class_name: "Foundation::Crm::Pipeline", inverse_of: :opportunities
      belongs_to :pipeline_stage, class_name: "Foundation::Crm::PipelineStage", inverse_of: :opportunities
      belongs_to :company, class_name: "Foundation::Crm::Company", optional: true, inverse_of: :opportunities
      belongs_to :contact, class_name: "Foundation::Crm::Contact", optional: true, inverse_of: :opportunities
      belongs_to :owner, class_name: "User", optional: true

      has_many :notes, as: :notable, class_name: "Foundation::Crm::Note", dependent: :destroy
      has_many :tasks, as: :taskable, class_name: "Foundation::Crm::Task", dependent: :nullify
      has_many :activities, as: :trackable, class_name: "Foundation::Crm::Activity", dependent: :destroy
      has_many :taggings, as: :taggable, class_name: "Foundation::Crm::Tagging", dependent: :destroy
      has_many :tags, through: :taggings

      validates :name, presence: true, length: { maximum: 200 }
      validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :currency, format: { with: /\A[A-Z]{3}\z/ }
      validates :status, inclusion: { in: STATUSES }
      validates :description, length: { maximum: 10_000 }
      validate :associations_in_same_organization
      validate :stage_belongs_to_pipeline

      before_validation :normalize_fields
      before_validation :sync_status_from_stage

      scope :ordered, -> { order(updated_at: :desc, id: :desc) }
      scope :owned_by, ->(user) { where(owner_id: user.id) }
      scope :with_status, ->(status) {
        status.to_s.presence_in(STATUSES) ? where(status: status) : all
      }
      scope :in_stage, ->(stage_id) {
        stage_id.present? ? where(pipeline_stage_id: stage_id) : all
      }
      scope :search, ->(query) {
        q = query.to_s.strip
        next all if q.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
        where("name ILIKE :q", q: pattern)
      }

      def display_name
        name
      end

      def move_to_stage!(stage, actor:)
        raise ArgumentError, "stage required" unless stage
        raise ArgumentError, "stage organization mismatch" unless stage.organization_id == organization_id
        raise ArgumentError, "stage pipeline mismatch" unless stage.pipeline_id == pipeline_id

        previous_stage = pipeline_stage
        previous_status = status
        self.pipeline_stage = stage
        self.status = stage.opportunity_status
        save!
        ActivityRecorder.record!(
          organization: organization,
          actor: actor,
          trackable: self,
          kind: "stage_changed",
          summary: "Moved from #{previous_stage&.name || 'none'} to #{stage.name}",
          metadata: {
            from_stage_id: previous_stage&.id,
            to_stage_id: stage.id,
            from_status: previous_status,
            to_status: status
          }
        )
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

      private

      def normalize_fields
        self.name = name.to_s.strip
        self.currency = currency.to_s.strip.upcase.presence || "USD"
        self.amount_cents = 0 if amount_cents.nil?
        self.status = "open" if status.blank?
        self.description = description.to_s
      end

      def sync_status_from_stage
        return unless pipeline_stage

        self.status = pipeline_stage.opportunity_status
      end

      def associations_in_same_organization
        %i[pipeline pipeline_stage company contact].each do |assoc|
          record = public_send(assoc)
          next if record.blank? || organization_id.blank?
          next if record.organization_id == organization_id

          errors.add(assoc, "must belong to the same organization")
        end
      end

      def stage_belongs_to_pipeline
        return if pipeline.blank? || pipeline_stage.blank?
        return if pipeline_stage.pipeline_id == pipeline.id

        errors.add(:pipeline_stage, "must belong to the selected pipeline")
      end
    end
  end
end
