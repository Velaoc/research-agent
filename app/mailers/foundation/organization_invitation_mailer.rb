# Delivers organization invitations (SPEC M4.2) with a signed, expiring
# acceptance link. Registered as the organizations gem's invitation mailer
# (config/initializers/organizations.rb), so the gem's send and resend
# paths both come through here and inherit the M2 mailer defaults.
class Foundation::OrganizationInvitationMailer < ApplicationMailer
  def invitation_email(invitation)
    @invitation = invitation
    @organization = invitation.organization
    @inviter_label = invitation.invited_by&.email || "A member"
    @accept_url = organization_invitation_link_url(signed_token(invitation))

    mail to: invitation.email,
      subject: "You have been invited to join #{@organization.name}"
  end

  private

  # The emailed token is cryptographically signed and expires together with
  # the invitation record, so a leaked link is useless once the invitation
  # lapses or is revoked.
  def signed_token(invitation)
    invitation.signed_id(purpose: :organization_invitation, expires_at: invitation.expires_at)
  end
end
