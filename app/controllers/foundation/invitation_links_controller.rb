# Redeems the signed, expiring token carried by organization invitation
# emails (SPEC M4.2). A valid token lands on the public acceptance page for
# its invitation; a tampered or expired one falls back to sign-in with an
# explanation. The invitation's own stored expiry is enforced again on the
# accept page, so a stale link can never outlive the invitation.
class Foundation::InvitationLinksController < ApplicationController
  def show
    invitation = Organizations::Invitation.find_signed(
      params[:signed_token], purpose: :organization_invitation
    )

    if invitation
      redirect_to organizations.invitation_path(invitation.token)
    else
      redirect_to new_user_session_path,
        alert: "That invitation link is invalid or has expired. Please ask for a new invitation."
    end
  end
end
