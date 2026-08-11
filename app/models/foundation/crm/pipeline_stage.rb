# frozen_string_literal: true

module Foundation
  module Crm
    class PipelineStage < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_pipeline_stages"

      belongs_to :pipeline, class_name: "Foundation::Crm::Pipeline", inverse_of: :stages
      has_many :opportunities, class_name: "Foundation::Crm::Opportunity", dependent: :restrict_with_error, inverse_of: :pipeline_stage

      validates :name, presence: true, length: { maximum: 120 }
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :probability, numericality: { only_integer: true, in: 0..100 }
      validate :pipeline_in_same_organization
      validate :not_both_closed

      before_validation :normalize_fields
      before_validation :sync_organization_from_pipeline

      scope :ordered, -> { order(:position, :id) }

      def closed?
        closed_won? || closed_lost?
      end

      def opportunity_status
        return "won" if closed_won?
        return "lost" if closed_lost?

        "open"
      end

      private

      def normalize_fields
        self.name = name.to_s.strip
        self.position = 0 if position.nil?
        self.probability = 0 if probability.nil?
        self.closed_won = false if closed_won.nil?
        self.closed_lost = false if closed_lost.nil?
      end

      def sync_organization_from_pipeline
        self.organization_id = pipeline.organization_id if pipeline
      end

      def pipeline_in_same_organization
        return if pipeline.blank? || organization_id.blank?
        return if pipeline.organization_id == organization_id

        errors.add(:pipeline, "must belong to the same organization")
      end

      def not_both_closed
        errors.add(:base, "Stage cannot be both won and lost") if closed_won? && closed_lost?
      end
    end
  end
end
