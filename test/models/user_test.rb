require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(attributes = {})
    User.new({
      email: "new-user@example.com",
      password: "a perfectly long password",
      password_confirmation: "a perfectly long password",
      legal_assent: "1"
    }.merge(attributes))
  end

  test "valid with a long password and legal assent" do
    assert_predicate build_user, :valid?
  end

  test "rejects passwords shorter than 12 characters" do
    user = build_user(password: "elevenchars", password_confirmation: "elevenchars")

    assert_not user.valid?
    assert user.errors[:password].any? { |message| message.include?("12") }
  end

  test "requires legal assent on create" do
    assert_not build_user(legal_assent: nil).valid?, "a missing assent param must not pass"
    assert_not build_user(legal_assent: "0").valid?, "an unticked checkbox must not pass"
    assert_predicate build_user(legal_assent: "1"), :valid?
  end

  test "does not require legal assent again on later saves" do
    user = users(:confirmed)
    user.email = "renamed@example.com"

    assert_predicate user, :valid?
  end

  test "rejects disposable email domains on create" do
    Nondisposable::DisposableDomain.create!(name: "burner.example")
    user = build_user(email: "someone@burner.example")

    assert_not user.valid?
    assert user.errors[:email].present?
  end

  test "keeps accounts that predate a domain being blocklisted usable" do
    user = users(:confirmed)
    Nondisposable::DisposableDomain.create!(name: user.email.split("@").last)

    assert_predicate user, :valid?, "the disposable check applies only at registration"
  end

  test "new accounts require confirmation outside offline preview" do
    with_env("VELA_HOLODEX_PREVIEW" => nil, "SMTP_ADDRESS" => nil) do
      user = build_user.tap(&:save!)

      assert_not user.confirmed?
      assert_predicate user.confirmation_token, :present?
    end
  end

  test "new accounts require confirmation in preview mode with an SMTP relay" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "SMTP_ADDRESS" => "smtp.example.com") do
      user = build_user.tap(&:save!)

      assert_not user.confirmed?
    end
  end

  test "new accounts are confirmed immediately in offline preview mode" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "SMTP_ADDRESS" => nil) do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        user = build_user.tap(&:save!)

        assert_predicate user, :confirmed?
      end
    end
  end

  test "locks the account after too many failed attempts" do
    user = users(:confirmed)

    User.maximum_attempts.times { user.valid_for_authentication? { false } }

    assert_predicate user.reload, :access_locked?
  end
end
