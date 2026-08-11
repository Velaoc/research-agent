require "test_helper"

class ReauthenticationSweepJobTest < ActiveJob::TestCase
  test "drops attempts older than the rate-limit window and keeps recent ones" do
    stale = Foundation::ReauthenticationAttempt.create!(
      key_digest: "stale", kind: "account", created_at: 2.days.ago
    )
    recent = Foundation::ReauthenticationAttempt.create!(
      key_digest: "recent", kind: "account", created_at: 1.minute.ago
    )

    ReauthenticationSweepJob.perform_now

    assert_not Foundation::ReauthenticationAttempt.exists?(stale.id),
      "expired attempts must not accumulate — the limiter only reads a recent window"
    assert Foundation::ReauthenticationAttempt.exists?(recent.id),
      "sweeping must not disarm the limiter for attempts still inside the window"
  end
end
