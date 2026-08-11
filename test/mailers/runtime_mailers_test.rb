require "test_helper"

class RuntimeMailersTest < ActionMailer::TestCase
  CANONICAL_HOST = "daily.holodex.test"
  IDENTITY_ADDRESS = "noreply@daily.holodex.test"

  test "Devise confirmation reset and unlock mail use canonical host and app identity" do
    with_runtime_mail do
      user = User.create!(
        email: "runtime-mail@example.com",
        password: "a perfectly long password",
        password_confirmation: "a perfectly long password",
        legal_assent: "1"
      )
      confirmation = ActionMailer::Base.deliveries.last

      users(:confirmed).send_reset_password_instructions
      reset = ActionMailer::Base.deliveries.last

      users(:confirmed).lock_access!
      unlock = ActionMailer::Base.deliveries.last

      [ confirmation, reset, unlock ].each { |mail| assert_runtime_mail(mail) }
      assert_match %r{https://#{CANONICAL_HOST}/users/confirmation}, confirmation.body.encoded
      assert_match %r{https://#{CANONICAL_HOST}/users/password/edit}, reset.body.encoded
      assert_match %r{https://#{CANONICAL_HOST}/users/unlock}, unlock.body.encoded
      assert_not_predicate user.reload, :confirmed?
    end
  end

  test "organization invite uses canonical host and app identity" do
    with_runtime_mail do
      organization = Organizations::Organization.create!(name: "Runtime Mail Team")
      Organizations::Membership.create!(
        organization: organization,
        user: users(:confirmed),
        role: "owner"
      )
      invitation = organization.send_invite_to!("invitee@example.com", invited_by: users(:confirmed))
      invite = Foundation::OrganizationInvitationMailer.invitation_email(invitation).message

      assert_runtime_mail(invite)
      assert_match %r{https://#{CANONICAL_HOST}/invitations/mail/}, invite.body.encoded
    end
  end

  # foundation:module storefront
  test "storefront receipt uses canonical host and app identity" do
    with_runtime_mail do
      receipt = Foundation::Storefront::OrderMailer.receipt(create_storefront_order).message

      assert_runtime_mail(receipt)
      assert_match %r{https://#{CANONICAL_HOST}/storefront/orders/}, receipt.body.encoded
      assert_match %r{https://#{CANONICAL_HOST}/legal/terms}, receipt.body.encoded
      assert_match %r{https://#{CANONICAL_HOST}/legal/privacy}, receipt.text_part.body.decoded
      assert_no_match(/example\.com/, receipt.text_part.body.decoded)
      assert_match(/@#{Regexp.escape(CANONICAL_HOST)}\z/, receipt.message_id)
    end
  end
  # /foundation:module storefront

  private

  def with_runtime_mail(&block)
    ActionMailer::Base.deliveries.clear
    with_env(
      "APP_HOST" => "https://#{CANONICAL_HOST}",
      "MAILER_FROM" => "Holodex Preview <#{IDENTITY_ADDRESS}>"
    ) do
      block.call
    end
  end

  def assert_runtime_mail(mail)
    assert_equal [ IDENTITY_ADDRESS ], mail.from
    assert_equal [ IDENTITY_ADDRESS ], mail.reply_to
    assert_match "Holodex Preview", mail["From"].to_s
    assert_match "Holodex Preview", mail["Reply-To"].to_s
    assert_no_match(/attacker|from@example\.com/, mail.header.to_s)
  end
end
