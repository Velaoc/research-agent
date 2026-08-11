# frozen_string_literal: true

module Foundation
  module Crm
    class Task < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_tasks"

      STATUSES = %w[open done canceled].freeze
      TASKABLE_TYPES = %w[
        Foundation::Crm::Contact
        Foundation::Crm::Company
        Foundation::Crm::Lead
        Foundation::Crm::Opportunity
      ].freeze

      belongs_to :creator, class_name: "User"
      belongs_to :assignee, class_name: "User", optional: true
      belongs_to :taskable, polymorphic: true, optional: true

      has_many :activities, as: :trackable, class_name: "Foundation::Crm::Activity", dependent: :destroy

      validates :title, presence: true, length: { maximum: 200 }
      validates :description, length: { maximum: 10_000 }
      validates :status, inclusion: { in: STATUSES }
      validates :taskable_type, inclusion: { in: TASKABLE_TYPES }, allow_blank: true
      validate :taskable_in_same_organization

      before_validation :normalize_fields
      after_create :record_created_activity

      scope :ordered, -> { order(Arel.sql("due_on ASC NULLS LAST"), :id) }
      scope :open_tasks, -> { where(status: "open") }
      scope :with_status, ->(status) {
        status.to_s.presence_in(STATUSES) ? where(status: status) : all
      }
      scope :assigned_to, ->(user) { where(assignee_id: user.id) }
      scope :search, ->(query) {
        q = query.to_s.strip
        next all if q.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
        where("title ILIKE :q", q: pattern)
      }

      def self.taskable_model_for(type)
        case type.to_s
        when "Foundation::Crm::Contact" then Contact
        when "Foundation::Crm::Company" then Company
        when "Foundation::Crm::Lead" then Lead
        when "Foundation::Crm::Opportunity" then Opportunity
        end
      end

      def display_name
        title
      end

      def complete!(actor:)
        update!(status: "done", completed_at: Time.current)
        ActivityRecorder.record!(
          organization: organization,
          actor: actor,
          trackable: self,
          kind: "task_completed",
          summary: "Task completed: #{title}"
        )
        if taskable
          ActivityRecorder.record!(
            organization: organization,
            actor: actor,
            trackable: taskable,
            kind: "task_completed",
            summary: "Task completed: #{title}",
            metadata: { task_id: id }
          )
        end
      end

      private

      def normalize_fields
        self.title = title.to_s.strip
        self.description = description.to_s
        self.status = "open" if status.blank?
        self.completed_at = nil unless status == "done"
        self.completed_at ||= Time.current if status == "done"
      end

      def taskable_in_same_organization
        return if taskable.blank? || organization_id.blank?
        return unless taskable.respond_to?(:organization_id)
        return if taskable.organization_id == organization_id

        errors.add(:taskable, "must belong to the same organization")
      end

      def record_created_activity
        ActivityRecorder.record!(
          organization: organization,
          actor: creator,
          trackable: self,
          kind: "created",
          summary: "Task created: #{title}"
        )
        return unless taskable

        ActivityRecorder.record!(
          organization: organization,
          actor: creator,
          trackable: taskable,
          kind: "task_created",
          summary: "Task created: #{title}",
          metadata: { task_id: id }
        )
      end
    end
  end
end
