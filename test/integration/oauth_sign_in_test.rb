require "test_helper"

class OauthSignInTest < ActionDispatch::IntegrationTest
  include OmniauthTestHelpers

  test "a known identity signs its user in" do
    identity = identities(:oauth_only_google)
    stub_oauth(:google_oauth2, uid: identity.uid, email: identity.user.email)

    post user_google_oauth2_omniauth_authorize_path
    follow_redirect! # OmniAuth test mode bounces straight to the callback

    assert_redirected_to root_path
    follow_redirect!
    assert_select "button", text: "Sign out"
  end

  test "an OAuth email matching an existing account is never auto-merged" do
    user = users(:confirmed)
    stub_oauth(:github, uid: "uid-the-app-has-never-seen", email: user.email)

    assert_no_difference [ "User.count", "Identity.count" ] do
      post user_github_omniauth_authorize_path
      follow_redirect!
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_select "p[role=alert]", text: /already exists/

    # And nobody got signed in along the way.
    get root_path
    assert_select "button", text: "Sign out", count: 0
  end

  test "a provider that shares no email cannot proceed" do
    stub_oauth(:github, uid: "uid-without-email", email: nil)

    assert_no_difference "User.count" do
      post user_github_omniauth_authorize_path
      follow_redirect!
    end

    assert_redirected_to new_user_session_path
  end

  test "provider buttons appear only for configured providers" do
    no_oauth_env = {
      "GOOGLE_OAUTH_CLIENT_ID" => nil, "GOOGLE_OAUTH_CLIENT_SECRET" => nil,
      "GITHUB_OAUTH_CLIENT_ID" => nil, "GITHUB_OAUTH_CLIENT_SECRET" => nil
    }

    with_env(no_oauth_env) do
      get new_user_session_path
      assert_select "button", text: "Continue with Google", count: 0
      assert_select "button", text: "Continue with GitHub", count: 0
    end

    with_env(no_oauth_env.merge("GOOGLE_OAUTH_CLIENT_ID" => "id", "GOOGLE_OAUTH_CLIENT_SECRET" => "secret")) do
      get new_user_session_path
      assert_select "button", text: "Continue with Google", count: 1
      assert_select "button", text: "Continue with GitHub", count: 0

      get new_user_registration_path
      assert_select "button", text: "Continue with Google", count: 1
    end
  end
end
