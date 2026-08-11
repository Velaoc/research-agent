# frozen_string_literal: true

require "test_helper"

class MailDesignTest < ActionMailer::TestCase
  LIGHT = JSON.parse(Rails.root.join("config/material_tokens.json").read).fetch("schemes").fetch("light")

  test "devise confirmation mail is multipart with inline MD3 styles" do
    user = User.create!(
      email: "mail-design@example.com",
      password: "a perfectly long password",
      password_confirmation: "a perfectly long password",
      legal_assent: "1"
    )
    mail = ActionMailer::Base.deliveries.last

    assert_multipart_mail mail
    html = mail.html_part.body.decoded
    assert_inline_branded_html html
    assert_match(/Confirm my account/, html)
    assert_match %r{/users/confirmation}, html
    assert_match user.email, mail.text_part.body.decoded
  end

  test "devise reset unlock email-changed and password-change mails are multipart" do
    user = users(:confirmed)

    user.send_reset_password_instructions
    reset = ActionMailer::Base.deliveries.last

    user.lock_access!
    unlock = ActionMailer::Base.deliveries.last

    email_changed = Devise.mailer.email_changed(user).message
    password_change = Devise.mailer.password_change(user).message

    [ reset, unlock, email_changed, password_change ].each do |mail|
      assert_multipart_mail mail
      assert_inline_branded_html mail.html_part.body.decoded
    end
  end

  test "organization invitation uses branded inline layout" do
    organization = Organizations::Organization.create!(name: "Mail Design Team")
    Organizations::Membership.create!(
      organization: organization,
      user: users(:confirmed),
      role: "owner"
    )
    invitation = organization.send_invite_to!("design-invitee@example.com", invited_by: users(:confirmed))
    invite = Foundation::OrganizationInvitationMailer.invitation_email(invitation).message

    assert_multipart_mail invite
    assert_inline_branded_html invite.html_part.body.decoded
    invite_html = invite.html_part.body.decoded
    assert_match(/Accept the invitation/, invite_html)
    assert_includes invite_html, "background-color: #{LIGHT.fetch("primary")}"
  end

  # foundation:module storefront
  test "storefront receipt uses branded inline layout" do
    receipt = Foundation::Storefront::OrderMailer.receipt(create_storefront_order).message

    assert_multipart_mail receipt
    assert_inline_branded_html receipt.html_part.body.decoded
    receipt_html = receipt.html_part.body.decoded
    assert_match(/View your receipt/, receipt_html)
    assert_match(/Terms of Service/, receipt_html)
    assert_includes receipt_html, "background-color: #{LIGHT.fetch("primary")}"
  end
  # /foundation:module storefront

  test "mailer helper colours match committed light scheme tokens" do
    helper = Object.new.extend(Foundation::MailerHelper)

    assert_equal LIGHT.fetch("primary"), helper.mail_color("primary")
    assert_equal LIGHT.fetch("on-primary"), helper.mail_color("on-primary")
    assert_equal LIGHT.fetch("surface"), helper.mail_color("surface")
    assert_equal LIGHT.fetch("on-surface"), helper.mail_color("on-surface")
    assert_match(/background-color: #{Regexp.escape(LIGHT.fetch("primary"))}/, helper.mail_button_style)
    assert_match(/color: #{Regexp.escape(LIGHT.fetch("on-primary"))}/, helper.mail_button_style)
  end

  private

  def assert_multipart_mail(mail)
    assert_equal "multipart/alternative", mail.mime_type
    assert mail.html_part.present?, "expected HTML part"
    assert mail.text_part.present?, "expected text part"
    assert_operator mail.text_part.body.decoded.strip.length, :>, 0
  end

  def assert_inline_branded_html(html)
    assert_includes html, 'style="'
    assert_includes html, "background-color: #{LIGHT.fetch("surface")}"
    assert_includes html, "color: #{LIGHT.fetch("on-surface")}"
    assert_includes html, "color: #{LIGHT.fetch("primary")}"
    assert_includes html, Rails.configuration.x.foundation[:application_name]
    assert_includes html, "border-radius: 16px"
    assert_includes html, "font-family: Inter"

    body = html[/<body[\s\S]*?<\/body>/i].to_s
    assert_match(/style="/, body)
    assert_no_match(/class="[^"]*md-button/, body)
    assert_match(/style="[^"]*background-color:\s*#{Regexp.escape(LIGHT.fetch("surface"))}/, body)

    # Head may carry progressive dark-mode hints, but stripping it must leave
    # a still-styled message with brand roles on the elements themselves.
    stripped = html.sub(/<head[\s\S]*?<\/head>/i, "")
    assert_match(/style="[^"]*background-color:\s*#{Regexp.escape(LIGHT.fetch("surface"))}/, stripped)
    assert_match(/style="[^"]*color:\s*#{Regexp.escape(LIGHT.fetch("on-surface"))}/, stripped)
    assert_match(/style="[^"]*color:\s*#{Regexp.escape(LIGHT.fetch("primary"))}/, stripped)
  end
end
