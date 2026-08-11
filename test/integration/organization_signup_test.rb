require "test_helper"

# SPEC M4.1/M4.2: every fresh signup gets a personal organization; a signup
# that arrives through an organization invitation joins the inviting
# workspace instead — on both the password path and the OAuth assent path.
class OrganizationSignupTest < ActionDispatch::IntegrationTest
  include OmniauthTestHelpers

  def sign_up_params(email:)
    { user: {
      email: email,
      password: "a perfectly long password",
      password_confirmation: "a perfectly long password",
      legal_assent: "1"
    } }
  end

  def create_org_with_owner(owner, name: "Acme")
    org = Organizations::Organization.create!(name: name)
    Organizations::Membership.create!(user: owner, organization: org, role: "owner")
    org
  end

  test "password signup creates a personal organization owned by the new user" do
    post user_registration_path, params: sign_up_params(email: "wren@example.com")

    user = User.find_by!(email: "wren@example.com")
    organization = user.organizations.sole
    assert_equal "wren's workspace", organization.name
    assert user.is_owner_of?(organization)
  end

  test "OAuth assent signup creates a personal organization owned by the new user" do
    stub_oauth(:google_oauth2, uid: "uid-org-fresh", email: "newcomer@example.com")
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!
    post oauth_assent_path, params: { legal_assent: "1" }

    user = User.find_by!(email: "newcomer@example.com")
    organization = user.organizations.sole
    assert_equal "newcomer's workspace", organization.name
    assert user.is_owner_of?(organization)
  end

  test "invited password signup joins the inviting organization and gets no personal one" do
    owner = users(:confirmed)
    org = create_org_with_owner(owner)
    invitation = org.send_invite_to!("invitee@example.com", invited_by: owner)

    post organizations.accept_invitation_path(invitation.token)
    assert_redirected_to new_user_registration_path

    post user_registration_path, params: sign_up_params(email: "invitee@example.com")

    user = User.find_by!(email: "invitee@example.com")
    assert_equal [ org.id ], user.organizations.pluck(:id)
    assert_equal :member, user.role_in(org)
    assert_predicate invitation.reload, :accepted?
  end

  test "registering with an email the invitation was not sent to still gets a personal organization" do
    owner = users(:confirmed)
    org = create_org_with_owner(owner)
    invitation = org.send_invite_to!("invitee@example.com", invited_by: owner)

    post organizations.accept_invitation_path(invitation.token)
    post user_registration_path, params: sign_up_params(email: "someone-else@example.com")

    user = User.find_by!(email: "someone-else@example.com")
    assert_equal "someone-else's workspace", user.organizations.sole.name
    assert_not user.is_member_of?(org)
    assert_predicate invitation.reload, :pending?
  end

  test "invited OAuth signup joins the inviting organization and gets no personal one" do
    owner = users(:confirmed)
    org = create_org_with_owner(owner)
    invitation = org.send_invite_to!("newcomer@example.com", invited_by: owner)

    post organizations.accept_invitation_path(invitation.token)
    assert_redirected_to new_user_registration_path

    stub_oauth(:google_oauth2, uid: "uid-org-invited", email: "newcomer@example.com")
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!
    post oauth_assent_path, params: { legal_assent: "1" }

    user = User.find_by!(email: "newcomer@example.com")
    assert_equal [ org.id ], user.organizations.pluck(:id)
    assert_equal :member, user.role_in(org)
    assert_predicate invitation.reload, :accepted?
  end
end
