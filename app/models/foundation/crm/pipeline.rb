# frozen_string_literal: true

module Foundation
  module Crm
    class Pipeline < ApplicationRecord
      include OrganizationScoped

      self.table_name = "crm_pipelines"

      DEFAULT_STAGES = [
        { name: "Qualification", position: 0, probability: 10 },
        { name: "Needs analysis", position: 1, probability: 25 },
        { name: "Proposal", position: 2, probability: 50 },
        { name: "Negotiation", position: 3, probability: 75 },
        { name: "Closed won", position: 4, probability: 100, closed_won: true },
        { name: "Closed lost", position: 5, probability: 0, closed_lost: true }
      ].freeze

      has_many :stages, -> { order(:position, :id) },
        class_name: "Foundation::Crm::PipelineStage",
        dependent: :destroy,
        inverse_of: :pipeline
      has_many :opportunities, class_name: "Foundation::Crm::Opportunity", dependent: :restrict_with_error, inverse_of: :pipeline

      validates :name, presence: true, length: { maximum: 120 }, uniqueness: { scope: :organization_id, case_sensitive: false }
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      before_validation :normalize_fields

      scope :ordered, -> { order(:position, :id) }

      def self.ensure_default!(organization)
        existing = for_organization(organization).ordered.first
        return existing if existing

        transaction do
          pipeline = create!(organization: organization, name: "Sales", position: 0)
          DEFAULT_STAGES.each do |attrs|
            pipeline.stages.create!(attrs.merge(organization: organization))
          end
          pipeline
        end
      end

      def open_stages
        stages.reject(&:closed?)
      end

      private

      def normalize_fields
        self.name = name.to_s.strip
        self.position = 0 if position.nil?
      end
    end
  end
end
