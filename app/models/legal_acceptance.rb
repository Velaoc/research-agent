# One row per assent event: which versions of the terms and privacy policy a
# user accepted, when, from where, and in what flow (context, e.g. "signup").
# Rows are written at registration and kept for the life of the account as an
# audit trail; they are never updated in place.
class LegalAcceptance < ApplicationRecord
  belongs_to :user

  validates :terms_version, :privacy_version, :accepted_at, :context, presence: true

  # Writes the assent row for a signup that just happened inside `request`.
  # Both signup flows (password registration and the OAuth interstitial)
  # funnel through here so the captured fields stay identical.
  def self.record!(user:, request:, context:)
    create!(
      user: user,
      terms_version: Foundation::Legal::TERMS_VERSION,
      privacy_version: Foundation::Legal::PRIVACY_VERSION,
      accepted_at: Time.current,
      ip: request.remote_ip,
      user_agent: request.user_agent.to_s.byteslice(0, 255),
      context: context
    )
  end
end
