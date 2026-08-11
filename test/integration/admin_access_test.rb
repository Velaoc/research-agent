require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery"

  setup do
    @admin = users(:admin)
    @regular = users(:confirmed)
    @organization = Organizations::Organization.create!(name: "Admin Visibility Lab")
    @membership = Organizations::Membership.create!(
      organization: @organization,
      user: @regular,
      role: "owner"
    )
  end

  test "guests cannot match any admin surface" do
    admin_paths.each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "normal users and organization admins are not application admins" do
    sign_in_as(@regular)
    get "/admin/dashboard"
    assert_response :not_found

    @membership.update!(role: "admin")
    assert_equal :admin, @regular.role_in(@organization)
    assert_not_predicate @regular, :admin?

    get "/admin/dashboard"
    assert_response :not_found
    get "/admin/jobs"
    assert_response :not_found
  end

  test "application admins can read every installed resource" do
    invitation = Organizations::Invitation.create!(
      organization: @organization,
      invited_by: @admin,
      email: "invited@example.com",
      role: "member",
      expires_at: 2.days.from_now
    )
    sign_in_as(@admin)
    session_row = @admin.sessions.live.first

    [
      "/admin/dashboard",
      "/admin/users",
      "/admin/users/#{@regular.id}",
      "/admin/organizations",
      "/admin/organizations/#{@organization.id}",
      "/admin/memberships",
      "/admin/memberships/#{@membership.id}",
      "/admin/invitations",
      "/admin/invitations/#{invitation.id}",
      "/admin/sessions",
      "/admin/sessions/#{session_row.id}",
      "/admin/login-activity"
    ].each do |path|
      get path
      assert_response :success, path
    end

    get "/admin/jobs"
    assert_response :success
  end

  test "resources expose no generic write endpoints" do
    sign_in_as(@admin)

    post "/admin/users", params: { user: { email: "created@example.com", admin: true } }
    assert_response :not_found
    patch "/admin/users/#{@regular.id}", params: { user: { admin: true } }
    assert_response :not_found
    delete "/admin/users/#{@regular.id}"
    assert_response :not_found
    get "/admin/users/new"
    assert_response :not_found
    get "/admin/users/#{@regular.id}/edit"
    assert_response :not_found
  end

  test "admin pages never render authentication, invitation, or session secrets" do
    @regular.update_columns(
      reset_password_token: "RESET-SECRET-M6",
      confirmation_token: "CONFIRM-SECRET-M6",
      unlock_token: "UNLOCK-SECRET-M6"
    )
    invitation = Organizations::Invitation.create!(
      organization: @organization,
      invited_by: @admin,
      email: "secret-check@example.com",
      role: "member",
      token: "INVITATION-SECRET-M6",
      expires_at: 2.days.from_now
    )
    sign_in_as(@admin)
    session_row = @admin.sessions.live.first
    session_row.update_columns(
      token_digest: Digest::SHA256.hexdigest("SESSION-SECRET-M6"),
      adoption_key: "ADOPTION-SECRET-M6"
    )

    get "/admin/users/#{@regular.id}"
    assert_response :success
    assert_no_secret("RESET-SECRET-M6", "CONFIRM-SECRET-M6", "UNLOCK-SECRET-M6")

    get "/admin/invitations/#{invitation.id}"
    assert_response :success
    assert_no_secret("INVITATION-SECRET-M6")

    get "/admin/sessions/#{session_row.id}"
    assert_response :success
    assert_no_secret("SESSION-SECRET-M6", session_row.token_digest, "ADOPTION-SECRET-M6")
  end

  # foundation:module storefront
  test "dashboard links the enabled storefront admin from nav and body" do
    sign_in_as(@admin)
    get "/admin/dashboard"

    assert_response :success
    assert_select "h2", text: "Storefront administration"
    # Once in the shared nav, once in the dashboard body copy — the body link
    # replaced a stale placeholder that claimed the storefront wasn't
    # installed while it was live.
    assert_select "a[href='#{storefront_admin_products_path}']", count: 2
    assert_select "a[href='#{storefront_admin_orders_path}']", count: 2
    assert_select "a[href='#{storefront_admin_payment_events_path}']", count: 2
    assert_not Rails.application.routes.named_routes.route_defined?(:madmin_products)
    assert_not Rails.application.routes.named_routes.route_defined?(:madmin_orders)
  end
  # /foundation:module storefront

  private

  def admin_paths
    %w[
      /admin/dashboard
      /admin/users
      /admin/organizations
      /admin/memberships
      /admin/invitations
      /admin/sessions
      /admin/login-activity
      /admin/jobs
    ]
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
    assert_response :redirect
  end

  def assert_no_secret(*secrets)
    secrets.each { |secret| assert_not_includes response.body, secret }
  end
end
