require "test_helper"

class OauthSignupTest < ActionDispatch::IntegrationTest
  include OmniauthTestHelpers

  EMAIL = "newcomer@example.com"

  # Runs the OAuth round-trip for an unknown external account, landing on
  # the assent interstitial with the payload parked in the session.
  def start_oauth_signup(uid: "uid-brand-new", email: EMAIL)
    stub_oauth(:google_oauth2, uid: uid, email: email)
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect! # callback phase
  end

  test "a first-time OAuth user reaches the assent interstitial and no account exists yet" do
    assert_no_difference [ "User.count", "Identity.count" ] do
      start_oauth_signup
      assert_redirected_to oauth_assent_path

      follow_redirect!
      assert_response :success
      assert_select "input[type=checkbox][name=legal_assent]"
      assert_select "strong", text: EMAIL
    end
  end

  test "accepting assent creates a confirmed user with identity and acceptance record" do
    start_oauth_signup

    assert_difference [ "User.count", "Identity.count", "LegalAcceptance.count" ], 1 do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        post oauth_assent_path, params: { legal_assent: "1" }
      end
    end

    user = User.find_by!(email: EMAIL)
    assert_predicate user, :confirmed?
    assert_not user.password_configured?

    identity = user.identities.sole
    assert_equal "google_oauth2", identity.provider
    assert_equal "uid-brand-new", identity.uid

    acceptance = user.legal_acceptances.sole
    assert_equal "oauth_signup", acceptance.context
    assert_equal Foundation::Legal::TERMS_VERSION, acceptance.terms_version
    assert_equal Foundation::Legal::PRIVACY_VERSION, acceptance.privacy_version

    assert_redirected_to root_path
    follow_redirect!
    assert_select "button", text: "Sign out"
  end

  test "submitting the interstitial without ticking the box creates nothing" do
    start_oauth_signup

    assert_no_difference [ "User.count", "Identity.count", "LegalAcceptance.count" ] do
      post oauth_assent_path, params: {}
    end

    assert_response :unprocessable_content

    # The payload survives, so the user can still accept afterwards.
    post oauth_assent_path, params: { legal_assent: "1" }
    assert_redirected_to root_path
  end

  test "declining assent abandons the signup" do
    start_oauth_signup

    assert_no_difference [ "User.count", "Identity.count" ] do
      delete oauth_assent_path
    end
    assert_redirected_to new_user_session_path

    # The pending payload is gone: the interstitial no longer opens.
    get oauth_assent_path
    assert_redirected_to new_user_session_path

    post oauth_assent_path, params: { legal_assent: "1" }
    assert_redirected_to new_user_session_path
    assert_nil User.find_by(email: EMAIL)
  end

  test "the interstitial is unreachable without a pending OAuth payload" do
    get oauth_assent_path
    assert_redirected_to new_user_session_path

    assert_no_difference "User.count" do
      post oauth_assent_path, params: { legal_assent: "1" }
    end
    assert_redirected_to new_user_session_path
  end

  test "a signup that has been pending too long expires" do
    start_oauth_signup

    travel Foundation::OauthSignupsController::PENDING_TTL + 1.minute do
      assert_no_difference "User.count" do
        post oauth_assent_path, params: { legal_assent: "1" }
      end
      assert_redirected_to new_user_session_path
    end
  end
end
