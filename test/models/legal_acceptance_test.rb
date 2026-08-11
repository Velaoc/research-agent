require "test_helper"

class LegalAcceptanceTest < ActiveSupport::TestCase
  test "fixture record is valid" do
    assert_predicate legal_acceptances(:signup_confirmed), :valid?
  end

  test "requires versions, timestamp, and context" do
    acceptance = LegalAcceptance.new(user: users(:confirmed))

    assert_not acceptance.valid?
    assert acceptance.errors[:terms_version].present?
    assert acceptance.errors[:privacy_version].present?
    assert acceptance.errors[:accepted_at].present?
  end

  test "is destroyed with its user" do
    assert_difference -> { LegalAcceptance.count }, -1 do
      users(:confirmed).destroy!
    end
  end
end
