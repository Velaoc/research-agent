# frozen_string_literal: true

require "test_helper"

class ReauthenticationTest < ActionDispatch::IntegrationTest
  include OmniauthTestHelpers

  PASSWORD = "correct horse battery"
  GENERIC = Foundation::Reauthentication::GENERIC_FAILURE

  setup do
    @user = users(:confirmed)
  end

  def sign_in_as(user, password: PASSWORD)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  test "reauth interstitial requires sign-in" do
    get new_reauthentication_path
    assert_redirected_to new_user_session_path

    post reauthentication_path, params: { password: PASSWORD }
    assert_redirected_to new_user_session_path
  end

  test "wrong password leaves session live" do
    sign_in_as(@user)
    live_before = @user.sessions.live.count

    post reauthentication_path, params: { password: "definitely not the password" }
    assert_redirected_to new_reauthentication_path
    follow_redirect!
    assert_match(/#{Regexp.escape(GENERIC)}/, flash[:alert].to_s + response.body)
    assert_select "p[role=alert], .md-snackbar", text: /Confirmation failed/, count: 1

    get settings_connections_path
    assert_response :success
    assert_operator @user.sessions.live.count, :>=, live_before
  end

  test "wrong password and expired window share generic copy" do
    sign_in_as(@user)

    post reauthentication_path, params: { password: "bad password value" }
    follow_redirect!
    bad_password_body = response.body

    grant_reauthentication!
    travel Foundation::Reauthentication::WINDOW + 1.minute do
      delete settings_connection_path(identities(:confirmed_github))
      assert_redirected_to new_reauthentication_path
      follow_redirect!
      expired_body = response.body
      assert_includes bad_password_body, GENERIC
      assert_includes expired_body, GENERIC
      assert_not_includes expired_body, "wrong password"
      assert_not_includes expired_body, "expired"
    end
  end

  test "successful confirm opens 15 minute window" do
    sign_in_as(@user)
    post reauthentication_path, params: { password: PASSWORD }
    assert_response :redirect
    assert_not_equal new_reauthentication_path, path_only(response.redirect_url)

    delete settings_connection_path(identities(:confirmed_github))
    assert_redirected_to settings_connections_path
    assert_not Identity.exists?(identities(:confirmed_github).id)
  end

  test "window expiry returns user to interstitial" do
    sign_in_as(@user)
    grant_reauthentication!
    identity = identities(:confirmed_github)

    travel Foundation::Reauthentication::WINDOW + 1.minute do
      assert_no_difference "Identity.count" do
        delete settings_connection_path(identity)
      end
      assert_redirected_to new_reauthentication_path
      assert Identity.exists?(identity.id)
    end
  end

  test "off-origin return target refused" do
    sign_in_as(@user)

    %w[https://evil.example/phish //evil.example /\\evil].each do |evil|
      post reauthentication_path, params: { password: PASSWORD, return_to: evil }
      assert_response :redirect
      location = response.redirect_url
      assert_not_includes location, "evil.example"
      assert_not_includes location, "allow_other_host"
      uri = URI.parse(location)
      assert_includes %w[example.com www.example.com], uri.host
      assert_equal "/settings/sessions", uri.path
    end
  end

  test "path-absolute return target accepted" do
    sign_in_as(@user)
    post reauthentication_path, params: { password: PASSWORD, return_to: "/billing" }
    assert_redirected_to "/billing"
  end

  test "rate limiter trips on account key" do
    sign_in_as(@user)
    limit = Foundation::Reauthentication::RateLimit::LIMITS.fetch("account")

    limit.times do
      post reauthentication_path, params: { password: "wrong-password-attempt" }
      assert_redirected_to new_reauthentication_path
    end

    post reauthentication_path, params: { password: PASSWORD }
    assert_redirected_to new_reauthentication_path
    follow_redirect!
    assert_includes response.body, GENERIC

    delete settings_connection_path(identities(:confirmed_github))
    assert_redirected_to new_reauthentication_path
  end

  test "rate limiter trips on IP key" do
    limit = Foundation::Reauthentication::RateLimit::LIMITS.fetch("ip")
    headers = { "REMOTE_ADDR" => "203.0.113.50" }

    limit.times do |i|
      user = User.create!(
        email: "rate-ip-#{i}@example.com",
        password: PASSWORD,
        legal_assent: "1",
        confirmed_at: Time.current
      )
      delete destroy_user_session_path
      post user_session_path,
        params: { user: { email: user.email, password: PASSWORD } },
        headers: headers
      post reauthentication_path,
        params: { password: "wrong-#{i}" },
        headers: headers
    end

    delete destroy_user_session_path
    post user_session_path,
      params: { user: { email: @user.email, password: PASSWORD } },
      headers: headers
    post reauthentication_path, params: { password: PASSWORD }, headers: headers
    assert_redirected_to new_reauthentication_path
  end

  test "failed confirm does not create admin-style unlock side effects" do
    sign_in_as(@user)
    assert_not @user.reload.access_locked?

    6.times { post reauthentication_path, params: { password: "wrong-password-value" } }

    assert_not @user.reload.access_locked?
    get settings_connections_path
    assert_response :success
  end

  test "oauth-only user cannot open window with empty password" do
    user = users(:oauth_only)
    identity = identities(:oauth_only_google)
    stub_oauth(:google_oauth2, uid: identity.uid, email: user.email)
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!

    post reauthentication_path, params: { password: "" }
    assert_redirected_to new_reauthentication_path
    follow_redirect!
    assert_includes response.body, GENERIC

    get settings_connections_path
    assert_response :success
  end

  test "sign-out clears window" do
    sign_in_as(@user)
    grant_reauthentication!

    delete destroy_user_session_path
    sign_in_as(@user)

    delete settings_connection_path(identities(:confirmed_github))
    assert_redirected_to new_reauthentication_path
  end

  test "grant and deny emit audit events" do
    sign_in_as(@user)
    output = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)

    post reauthentication_path, params: {
      password: "wrong-secret-MUST-NOT-APPEAR",
      token: "RAW-PARAM-SECRET"
    }
    post reauthentication_path, params: { password: PASSWORD }

    lines = output.string.lines.select { |line| line.include?(Foundation::Reauthentication::Audit::EVENT_NAME) }
    assert_operator lines.size, :>=, 2

    lines.each do |line|
      payload = JSON.parse(line[line.index("{")..])
      assert payload["actor_id"].present?
      assert payload["request_id"].present?
      assert payload["outcome"].present?
      assert_not_includes line, "wrong-secret-MUST-NOT-APPEAR"
      assert_not_includes line, "RAW-PARAM-SECRET"
      assert_not payload.key?("params")
      assert_not payload.key?("password")
    end

    outcomes = lines.map { |line| JSON.parse(line[line.index("{")..]).fetch("outcome") }
    assert_includes outcomes, "denied"
    assert_includes outcomes, "granted"
  ensure
    Rails.logger = original
  end

  test "garbage sudo_until fails closed" do
    assert_not Foundation::Reauthentication.open_window?("not-a-time")
    assert_not Foundation::Reauthentication.open_window?({})
  end

  test "billing portal blocked without window" do
    organization = Organizations::Organization.create!(name: "Portal Gate")
    Organizations::Membership.create!(user: @user, organization: organization, role: "owner")
    customer = Pay::Stripe::Customer.create!(
      owner: organization, processor: "stripe", processor_id: "cus_reauth_portal", default: true
    )
    Pay::Stripe::Subscription.create!(
      customer: customer, name: "default", processor_id: "sub_reauth_portal",
      processor_plan: "price_pro_monthly", status: "active"
    )

    sign_in_as(@user)
    post organizations.switch_organization_path(organization)

    called = false
    portal = lambda do |**_|
      called = true
      "https://billing.stripe.test/blocked"
    end
    with_stubbed_singleton_method(Foundation::BillingGateway, :portal_url, portal) do
      post billing_portal_path
    end
    assert_redirected_to new_reauthentication_path
    assert_not called
  end

  test "billing portal allowed with window" do
    organization = Organizations::Organization.create!(name: "Portal Open")
    Organizations::Membership.create!(user: @user, organization: organization, role: "owner")
    customer = Pay::Stripe::Customer.create!(
      owner: organization, processor: "stripe", processor_id: "cus_reauth_open", default: true
    )
    Pay::Stripe::Subscription.create!(
      customer: customer, name: "default", processor_id: "sub_reauth_open",
      processor_plan: "price_pro_monthly", status: "active"
    )

    sign_in_as(@user)
    post organizations.switch_organization_path(organization)
    grant_reauthentication!

    portal = lambda { |**_| "https://billing.stripe.test/portal_ok" }
    with_stubbed_singleton_method(Foundation::BillingGateway, :portal_url, portal) do
      post billing_portal_path
    end
    assert_redirected_to "https://billing.stripe.test/portal_ok"
  end

  test "admin assign_plan blocked without window" do
    admin = users(:admin)
    organization = Organizations::Organization.create!(name: "Admin Gate Org")
    sign_in_as(admin)

    post assign_plan_madmin_organization_path(organization), params: { plan_key: "enterprise" }
    assert_redirected_to new_reauthentication_path
    assert_equal :free, organization.reload.current_pricing_plan.key
  end

  test "admin assign_plan allowed with window" do
    admin = users(:admin)
    organization = Organizations::Organization.create!(name: "Admin Open Org")
    sign_in_as(admin)
    grant_reauthentication!

    post assign_plan_madmin_organization_path(organization), params: { plan_key: "enterprise" }
    assert_redirected_to madmin_organization_path(organization)
    assert_equal :enterprise, organization.reload.current_pricing_plan.key
  end

  test "identity unlink blocked without window" do
    sign_in_as(@user)
    assert_no_difference "Identity.count" do
      delete settings_connection_path(identities(:confirmed_github))
    end
    assert_redirected_to new_reauthentication_path
  end

  test "identity unlink allowed with window" do
    sign_in_as(@user)
    grant_reauthentication!
    assert_difference "Identity.count", -1 do
      delete settings_connection_path(identities(:confirmed_github))
    end
  end

  test "registration update blocked without window" do
    sign_in_as(@user)
    put user_registration_path, params: {
      user: {
        email: "new-email@example.com",
        current_password: PASSWORD
      }
    }
    assert_redirected_to new_reauthentication_path
    assert_equal "confirmed@example.com", @user.reload.email
  end

  test "registration update allowed with window" do
    sign_in_as(@user)
    grant_reauthentication!
    put user_registration_path, params: {
      user: {
        email: "updated-email@example.com",
        password: "",
        password_confirmation: "",
        current_password: PASSWORD
      }
    }
    assert_response :redirect
    assert_equal "updated-email@example.com", @user.reload.unconfirmed_email
  end

  test "organization destroy blocked without window" do
    org = Organizations::Organization.create!(name: "Destroy Gate")
    Organizations::Membership.create!(user: @user, organization: org, role: "owner")
    sign_in_as(@user)
    post organizations.switch_organization_path(org)

    delete organizations.organization_path(org)
    assert Organizations::Organization.exists?(org.id)
    assert_redirected_to new_reauthentication_path
  end

  test "organization destroy allowed with window" do
    org = Organizations::Organization.create!(name: "Destroy Open")
    Organizations::Membership.create!(user: @user, organization: org, role: "owner")
    sign_in_as(@user)
    post organizations.switch_organization_path(org)
    grant_reauthentication!

    delete organizations.organization_path(org)
    assert_not Organizations::Organization.exists?(org.id)
  end

  test "oauth step-up grants window for linked provider" do
    sign_in_as(@user)
    stub_oauth(:github, uid: identities(:confirmed_github).uid, email: @user.email)

    complete_oauth_step_up!("github", return_to: "/billing")
    assert_redirected_to "/billing"

    delete settings_connection_path(identities(:confirmed_github))
    assert_redirected_to settings_connections_path
  end

  test "oauth step-up refuses unlinked provider" do
    sign_in_as(@user)
    assert_no_difference "Identity.count" do
      post oauth_reauthentication_path(provider: "google_oauth2")
    end
    assert_redirected_to new_reauthentication_path
  end

  test "oauth step-up refuses foreign identity and does not link" do
    sign_in_as(@user)
    foreign = identities(:oauth_only_google)

    # Start step-up for linked github, then complete a different provider
    # callback — provider mismatch must deny and never attach the foreign row.
    post oauth_reauthentication_path(provider: "github")
    assert_response :success
    stub_oauth(:google_oauth2, uid: foreign.uid, email: "any@example.com")
    post user_google_oauth2_omniauth_callback_path

    assert_redirected_to new_reauthentication_path
    assert_equal users(:oauth_only), foreign.reload.user
    assert_not @user.identities.exists?(provider: "google_oauth2")
  end

  test "oauth step-up does not grant when linking a brand-new identity mid-flow" do
    sign_in_as(@user)
    post oauth_reauthentication_path(provider: "github")
    assert_response :success
    stub_oauth(:github, uid: "brand-new-uid-not-linked", email: @user.email)
    assert_no_difference -> { @user.identities.count } do
      post user_github_omniauth_authorize_path
      follow_redirect!
    end
    assert_redirected_to new_reauthentication_path

    delete settings_connection_path(identities(:confirmed_github))
    assert_redirected_to new_reauthentication_path
  end

  test "oauth step-up return_to is re-sanitized on the way back" do
    sign_in_as(@user)
    stub_oauth(:github, uid: identities(:confirmed_github).uid, email: @user.email)
    complete_oauth_step_up!("github", return_to: "https://evil.example/phish")
    assert_response :redirect
    location = response.redirect_url
    assert_not_includes location, "evil.example"
  end

  private

  def path_only(url)
    URI.parse(url).path
  end

  def complete_oauth_step_up!(provider, return_to: nil)
    params = {}
    params[:return_to] = return_to if return_to
    post oauth_reauthentication_path(provider: provider), params: params
    assert_response :success
    post send(:"user_#{provider}_omniauth_authorize_path")
    follow_redirect!
  end
end
