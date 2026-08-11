class ResearchRun < ApplicationRecord
  belongs_to :user

  has_many :steps,
    -> { order(position: :asc) },
    class_name: "ResearchStep",
    dependent: :destroy,
    inverse_of: :research_run

  STATUSES = %w[queued running complete failed].freeze
  validates :question, presence: true, length: { maximum: 1000 }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
end
