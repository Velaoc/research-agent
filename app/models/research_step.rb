class ResearchStep < ApplicationRecord
  belongs_to :research_run

  STATUSES = %w[pending running complete failed].freeze
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc) }
end
