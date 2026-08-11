require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "requires a provider and a uid" do
    identity = Identity.new(user: users(:confirmed))

    assert_not identity.valid?
    assert identity.errors[:provider].any?
    assert identity.errors[:uid].any?
  end

  test "uid must be unique within a provider but may repeat across providers" do
    existing = identities(:confirmed_github)

    duplicate = Identity.new(user: users(:oauth_only), provider: existing.provider, uid: existing.uid)
    assert_not duplicate.valid?

    other_provider = Identity.new(user: users(:oauth_only), provider: "google_oauth2", uid: existing.uid)
    assert other_provider.valid?
  end

  test "a user may hold several identities" do
    user = users(:confirmed)
    user.identities.create!(provider: "google_oauth2", uid: "second-identity-uid")

    assert_equal 2, user.identities.count
  end

  test "removable_identity? demands a remaining sign-in method" do
    # Password on file: the only identity may still go.
    assert users(:confirmed).removable_identity?(identities(:confirmed_github))

    # No password and a single identity: locked in place.
    assert_not users(:oauth_only).removable_identity?(identities(:oauth_only_google))

    # A second identity frees the first.
    users(:oauth_only).identities.create!(provider: "github", uid: "freshly-linked-uid")
    assert users(:oauth_only).removable_identity?(identities(:oauth_only_google))
  end

  test "password_configured? distinguishes OAuth-only accounts" do
    assert users(:confirmed).password_configured?
    assert_not users(:oauth_only).password_configured?
  end
end
