require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  USER_AGENT = "SignupBrowser/2.0"

  def sign_up_params(overrides = {})
    { user: {
      email: "fresh@example.com",
      password: "a perfectly long password",
      password_confirmation: "a perfectly long password",
      legal_assent: "1"
    }.merge(overrides) }
  end

  test "signup form shows the assent checkbox linking to both legal documents" do
    get new_user_registration_path

    assert_response :success
    assert_select "input[type=checkbox][name='user[legal_assent]']"
    assert_select "a[href='#{legal_terms_path}']"
    assert_select "a[href='#{legal_privacy_path}']"
  end

  test "signup creates an unconfirmed user, records assent, and mails confirmation instructions" do
    assert_difference [ "User.count", "LegalAcceptance.count" ], 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post user_registration_path, params: sign_up_params, headers: { "User-Agent" => USER_AGENT }
      end
    end

    user = User.find_by!(email: "fresh@example.com")
    assert_not user.confirmed?

    acceptance = user.legal_acceptances.sole
    assert_equal Foundation::Legal::TERMS_VERSION, acceptance.terms_version
    assert_equal Foundation::Legal::PRIVACY_VERSION, acceptance.privacy_version
    assert_equal "signup", acceptance.context
    assert_equal USER_AGENT, acceptance.user_agent
    assert_predicate acceptance.accepted_at, :present?
    assert_predicate acceptance.ip, :present?
  end

  test "signup cannot self-promote to application admin" do
    post user_registration_path, params: sign_up_params(admin: "1")

    assert_response :redirect
    assert_not_predicate User.find_by!(email: "fresh@example.com"), :admin?
  end

  test "signup without the assent checkbox is rejected server-side" do
    assert_no_difference [ "User.count", "LegalAcceptance.count" ] do
      post user_registration_path, params: sign_up_params(legal_assent: "0")
      assert_response :unprocessable_content

      post user_registration_path, params: { user: sign_up_params[:user].except(:legal_assent) }
      assert_response :unprocessable_content
    end
  end

  test "signup with a disposable email address is rejected" do
    Nondisposable::DisposableDomain.create!(name: "burner.example")

    assert_no_difference "User.count" do
      post user_registration_path, params: sign_up_params(email: "sneaky@burner.example")
    end

    assert_response :unprocessable_content
  end

  test "signup in offline preview mode confirms the account immediately" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "SMTP_ADDRESS" => nil) do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        post user_registration_path, params: sign_up_params
      end
    end

    assert_predicate User.find_by!(email: "fresh@example.com"), :confirmed?
  end

  test "confirmation link from the email activates the account" do
    post user_registration_path, params: sign_up_params
    user = User.find_by!(email: "fresh@example.com")

    get user_confirmation_path(confirmation_token: user.confirmation_token)

    assert_predicate user.reload, :confirmed?
  end
end
