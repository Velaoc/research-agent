require "test_helper"

class OauthConnectionsTest < ActionDispatch::IntegrationTest
  include OmniauthTestHelpers

  PASSWORD = "correct horse battery" # matches test/fixtures/users.yml

  def sign_in_as(user, password: PASSWORD)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  test "the connections page requires sign-in" do
    get settings_connections_path
    assert_redirected_to new_user_session_path
  end

  test "the connections page lists linked providers with a disconnect control" do
    sign_in_as users(:confirmed)

    get settings_connections_path
    assert_response :success
    assert_select "button", text: "Disconnect", count: 1
  end

  test "a signed-in user can explicitly connect a provider" do
    sign_in_as users(:confirmed)
    stub_oauth(:google_oauth2, uid: "uid-fresh-connection", email: "any-address@example.com")

    assert_difference -> { users(:confirmed).identities.count }, 1 do
      post user_google_oauth2_omniauth_authorize_path
      follow_redirect!
    end

    assert_redirected_to settings_connections_path
    assert_equal "google_oauth2", users(:confirmed).identities.order(:created_at).last.provider
  end

  test "connecting an identity that belongs to someone else is refused" do
    sign_in_as users(:confirmed)
    other = identities(:oauth_only_google)
    stub_oauth(:google_oauth2, uid: other.uid, email: "any-address@example.com")

    assert_no_difference "Identity.count" do
      post user_google_oauth2_omniauth_authorize_path
      follow_redirect!
    end

    assert_redirected_to settings_connections_path
    assert_equal users(:oauth_only), other.reload.user
  end

  test "disconnecting is allowed while a password remains" do
    sign_in_as users(:confirmed)
    grant_reauthentication!

    assert_difference "Identity.count", -1 do
      delete settings_connection_path(identities(:confirmed_github))
    end

    assert_redirected_to settings_connections_path
  end

  test "disconnecting the last sign-in method is refused" do
    user = users(:oauth_only)
    identity = identities(:oauth_only_google)

    stub_oauth(:google_oauth2, uid: identity.uid, email: user.email)
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!

    # OAuth-only accounts confirm via the linked provider step-up path.
    stub_oauth(:google_oauth2, uid: identity.uid, email: user.email)
    post oauth_reauthentication_path(provider: "google_oauth2")
    assert_response :success
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!

    assert_no_difference "Identity.count" do
      delete settings_connection_path(identity)
    end

    assert_redirected_to settings_connections_path
    follow_redirect!
    assert_select "p[role=alert]", text: /only way to sign in/
  end

  test "one user cannot disconnect another user's identity" do
    sign_in_as users(:confirmed)
    grant_reauthentication!

    assert_no_difference "Identity.count" do
      delete settings_connection_path(identities(:oauth_only_google))
    end

    assert_response :not_found
  end
end
