# frozen_string_literal: true

# Drops expired step-up rate-limit rows. The limiter only ever reads a recent
# window, so older rows are dead weight that would otherwise grow without
# bound. Schedule daily (see config/recurring.yml).
class ReauthenticationSweepJob < ApplicationJob
  queue_as :default

  def perform
    Foundation::Reauthentication::RateLimit.purge!
  end
end
