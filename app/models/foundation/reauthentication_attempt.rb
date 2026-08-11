# frozen_string_literal: true

module Foundation
  class ReauthenticationAttempt < ApplicationRecord
    self.table_name = "reauthentication_attempts"

    validates :key_digest, presence: true
    validates :kind, inclusion: { in: %w[account ip] }
  end
end
