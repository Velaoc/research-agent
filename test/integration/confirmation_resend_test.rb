require "test_helper"

class ConfirmationResendTest < ActionDispatch::IntegrationTest
  setup do
    Users::ConfirmationsController::RATE_LIMIT_STORE.clear
  end

  test "resend form is reachable" do
    get new_user_confirmation_path

    assert_response :success
    assert_select "form[action='#{user_confirmation_path}']"
  end

  test "resend for an unconfirmed address mails instructions" do
    user = users(:unconfirmed)

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_confirmation_path, params: { user: { email: user.email } }
    end

    assert_redirected_to new_user_session_path
    assert_match(/if your email address exists/i, flash[:notice])
  end

  test "resend does not reveal whether an address is registered" do
    known = users(:unconfirmed).email
    unknown = "nobody-#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_confirmation_path, params: { user: { email: known } }
    end
    known_status = response.status
    known_location = response.location
    known_notice = flash[:notice]

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post user_confirmation_path, params: { user: { email: unknown } }
    end
    unknown_status = response.status
    unknown_location = response.location
    unknown_notice = flash[:notice]

    assert_equal known_status, unknown_status
    assert_equal known_location, unknown_location
    assert_equal known_notice, unknown_notice
    assert_match(/if your email address exists/i, known_notice)
  end

  test "resend for an already-confirmed address does not leak existence" do
    post user_confirmation_path, params: { user: { email: users(:confirmed).email } }

    assert_redirected_to new_user_session_path
    assert_match(/if your email address exists/i, flash[:notice])
  end

  test "confirmation resend is rate limited" do
    email = users(:unconfirmed).email

    5.times do
      post user_confirmation_path, params: { user: { email: email } }
      assert_response :redirect
    end

    post user_confirmation_path, params: { user: { email: email } }
    assert_response :too_many_requests
  end
end
