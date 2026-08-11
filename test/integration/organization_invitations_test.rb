require "test_helper"

# SPEC M4.2: email invitations carry signed, expiring tokens; accepting
# while signed in joins directly, accepting signed out routes through
# authentication; expired tokens (signed link or stored invitation) fail.
class OrganizationInvitationsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "correct horse battery"

  setup do
    @owner = users(:confirmed)
    @org = Organizations::Organization.create!(name: "Acme")
    Organizations::Membership.create!(user: @owner, organization: @org, role: "owner")
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

  test "inviting sends a mail whose signed link redeems to the acceptance page" do
    sign_in_and_switch(@owner)

    assert_difference "Organizations::Invitation.count", 1 do
      perform_enqueued_jobs do
        post organizations.organization_invitations_path,
          params: { invitation: { email: "guest@example.com", role: "member" } }
      end
    end

    invitation = Organizations::Invitation.last
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "guest@example.com" ], mail.to

    body = mail.text_part.body.to_s
    link = body[%r{https://[^/\s]+(/invitations/mail/\S+)}, 1]
    assert link, "expected the mail to carry a signed invitation link"
    assert_no_match(/#{Regexp.escape(invitation.token)}/, link,
      "the emailed link must carry the signed token, not the raw one")

    get link
    assert_redirected_to organizations.invitation_path(invitation.token)
  end

  test "members cannot send invitations" do
    member = create_user("member@example.com")
    Organizations::Membership.create!(user: member, organization: @org, role: "member")

    sign_in_and_switch(member)
    assert_no_difference "Organizations::Invitation.count" do
      post organizations.organization_invitations_path,
        params: { invitation: { email: "guest@example.com", role: "member" } }
    end
  end

  test "a signed-in user with the invited address accepts and joins immediately" do
    guest = create_user("guest@example.com")
    invitation = @org.send_invite_to!("guest@example.com", invited_by: @owner)

    sign_in_as(guest)
    post organizations.accept_invitation_path(invitation.token)

    assert guest.reload.is_member_of?(@org)
    assert_predicate invitation.reload, :accepted?

    # Acceptance also switches the session to the joined organization.
    get organizations.memberships_path
    assert_select "h1", text: /Acme/
  end

  test "a signed-out invitee with an existing account signs in and then joins" do
    guest = create_user("guest@example.com")
    invitation = @org.send_invite_to!("guest@example.com", invited_by: @owner)

    post organizations.accept_invitation_path(invitation.token)
    assert_redirected_to new_user_session_path

    sign_in_as(guest)
    assert guest.reload.is_member_of?(@org)
    assert_predicate invitation.reload, :accepted?
  end

  test "an expired invitation cannot be accepted" do
    guest = create_user("guest@example.com")
    invitation = @org.send_invite_to!("guest@example.com", invited_by: @owner)

    travel 8.days do
      sign_in_as(guest)
      post organizations.accept_invitation_path(invitation.token)

      assert_not guest.reload.is_member_of?(@org)
      assert_predicate invitation.reload, :expired?
    end
  end

  test "an expired signed mail token is rejected at the redeem step" do
    invitation = @org.send_invite_to!("guest@example.com", invited_by: @owner)
    signed = invitation.signed_id(purpose: :organization_invitation, expires_at: invitation.expires_at)

    travel 8.days do
      get organization_invitation_link_path(signed)
      assert_redirected_to new_user_session_path
      assert_match(/invalid or has expired/, flash[:alert])
    end
  end

  test "a tampered mail token is rejected at the redeem step" do
    get organization_invitation_link_path("not-a-real-signed-token")
    assert_redirected_to new_user_session_path
    assert_match(/invalid or has expired/, flash[:alert])
  end
end
