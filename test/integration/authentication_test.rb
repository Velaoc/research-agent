require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery" # matches test/fixtures/users.yml

  def sign_in_as(user, password: PASSWORD)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  test "a confirmed user can sign in and out" do
    sign_in_as users(:confirmed)
    assert_redirected_to root_path

    follow_redirect!
    assert_select "button", text: "Sign out"

    delete destroy_user_session_path
    assert_redirected_to root_path
  end

  test "an unconfirmed user cannot sign in" do
    sign_in_as users(:unconfirmed)

    follow_redirect!
    get root_path
    assert_select "button", text: "Sign out", count: 0
  end

  test "repeated failed sign-ins lock the account" do
    user = users(:confirmed)

    User.maximum_attempts.times { sign_in_as(user, password: "wrong password here") }

    assert_predicate user.reload, :access_locked?

    sign_in_as user
    assert_not response.redirect?, "a locked account must not sign in even with the right password"
  end

  test "password reset request mails instructions" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_password_path, params: { user: { email: users(:confirmed).email } }
    end
  end

  test "password reset enforces the 12-character minimum" do
    token = users(:confirmed).send_reset_password_instructions

    put user_password_path, params: { user: {
      reset_password_token: token,
      password: "elevenchars",
      password_confirmation: "elevenchars"
    } }
    assert_response :unprocessable_content

    put user_password_path, params: { user: {
      reset_password_token: token,
      password: "twelve chars now",
      password_confirmation: "twelve chars now"
    } }
    assert_redirected_to root_path
  end

  test "turnstile stays out of the way in test mode" do
    assert_not RailsCloudflareTurnstile.enabled?
    assert_not RailsCloudflareTurnstile.mock_enabled?

    get new_user_registration_path
    assert_response :success
    assert_select "div.cf-turnstile", count: 0
  end
end
