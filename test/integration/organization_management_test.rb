require "test_helper"

# SPEC M4.1/M4.3/M4.4: switching (session-persisted), the role permission
# matrix for rename/role-change/removal/transfer/delete, and the guards
# around sole owners and owner account deletion.
class OrganizationManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery"

  setup do
    @owner = users(:confirmed)
    @org = Organizations::Organization.create!(name: "Acme")
    Organizations::Membership.create!(user: @owner, organization: @org, role: "owner")

    @admin = create_user("admin@example.com")
    @member = create_user("member@example.com")
    @admin_membership = Organizations::Membership.create!(user: @admin, organization: @org, role: "admin")
    @member_membership = Organizations::Membership.create!(user: @member, organization: @org, role: "member")
  end

  def create_user(email)
    User.create!(email: email, password: PASSWORD, legal_assent: "1", confirmed_at: Time.current)
  end

  # Devise's require_no_authentication ignores a login attempt while a
  # session is active, so drop any current session first.
  def sign_in_as(user)
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
  end

  def sign_in_and_switch(user, org = @org)
    sign_in_as(user)
    post organizations.switch_organization_path(org)
  end

  test "switching organizations persists in the session across requests" do
    second = Organizations::Organization.create!(name: "Second Workspace")
    Organizations::Membership.create!(user: @owner, organization: second, role: "owner")

    sign_in_and_switch(@owner, @org)
    get organizations.memberships_path
    assert_select "h1", text: /Acme/

    post organizations.switch_organization_path(second)
    get organizations.memberships_path
    assert_select "h1", text: /Second Workspace/

    # A later, unrelated request still sees the switched organization.
    get organizations.memberships_path
    assert_select "h1", text: /Second Workspace/
  end

  test "admins can rename the organization, members cannot" do
    sign_in_and_switch(@admin)
    patch organizations.organization_path(@org), params: { organization: { name: "Renamed" } }
    assert_equal "Renamed", @org.reload.name

    sign_in_and_switch(@member)
    patch organizations.organization_path(@org), params: { organization: { name: "Hijacked" } }
    assert_equal "Renamed", @org.reload.name
  end

  test "only the owner can change member roles" do
    sign_in_and_switch(@owner)
    patch organizations.membership_path(@member_membership), params: { membership: { role: "admin" } }
    assert_equal "admin", @member_membership.reload.role

    sign_in_and_switch(@admin)
    patch organizations.membership_path(@member_membership), params: { membership: { role: "member" } }
    assert_equal "admin", @member_membership.reload.role
  end

  test "admins can remove members, members cannot remove anyone, and the owner is protected" do
    sign_in_and_switch(@member)
    delete organizations.membership_path(@admin_membership)
    assert Organizations::Membership.exists?(@admin_membership.id)

    owner_membership = @org.owner_membership
    sign_in_and_switch(@admin)
    delete organizations.membership_path(owner_membership)
    assert_redirected_to organizations.memberships_path
    assert_match(/owner/i, flash[:alert])
    assert Organizations::Membership.exists?(owner_membership.id)

    delete organizations.membership_path(@member_membership)
    assert_not Organizations::Membership.exists?(@member_membership.id)
  end

  test "only the owner can transfer ownership, and roles swap when they do" do
    sign_in_and_switch(@admin)
    post organizations.transfer_ownership_membership_path(@admin_membership)
    assert_equal "admin", @admin_membership.reload.role

    sign_in_and_switch(@owner)
    post organizations.transfer_ownership_membership_path(@admin_membership)
    assert_equal "owner", @admin_membership.reload.role
    assert_equal :admin, @owner.role_in(@org.reload)
  end

  test "only the owner can delete the organization" do
    sign_in_and_switch(@admin)
    grant_reauthentication!
    delete organizations.organization_path(@org)
    assert Organizations::Organization.exists?(@org.id)

    sign_in_and_switch(@owner)
    grant_reauthentication!
    delete organizations.organization_path(@org)
    assert_not Organizations::Organization.exists?(@org.id)
  end

  test "the sole owner cannot leave until ownership is transferred" do
    sign_in_and_switch(@owner)
    delete organizations.leave_memberships_path
    assert @owner.reload.is_member_of?(@org)

    @org.transfer_ownership_to!(@admin)
    delete organizations.leave_memberships_path
    assert_not @owner.reload.is_member_of?(@org)
  end

  test "creating an additional organization makes the creator its owner and switches to it" do
    sign_in_and_switch(@member)
    post organizations.organizations_path, params: { organization: { name: "Side Project" } }

    side = Organizations::Organization.find_by!(name: "Side Project")
    assert @member.is_owner_of?(side)

    get organizations.memberships_path
    assert_select "h1", text: /Side Project/
  end

  test "account deletion is blocked while owning a workspace with other members" do
    sign_in_as(@owner)
    delete user_registration_path
    assert_redirected_to edit_user_registration_path
    assert User.exists?(@owner.id)
    assert Organizations::Organization.exists?(@org.id)
  end

  test "account deletion succeeds when owned workspaces have no other members" do
    solo = create_user("solo@example.com")
    personal = solo.organizations.sole

    sign_in_as(solo)
    delete user_registration_path
    assert_not User.exists?(solo.id)
    assert_not Organizations::Organization.exists?(personal.id)
  end
end
