class ApplicationMailer < ActionMailer::Base
  default from: -> { Foundation.runtime_config.mailer_from },
    reply_to: -> { Foundation.runtime_config.mailer_from }

  helper Foundation::MailerHelper
  after_action :enforce_application_mail_identity
  layout "mailer"

  def default_url_options
    Foundation.runtime_config.url_options
  end

  private

  # Subclasses and third-party mailers inheriting from ApplicationMailer
  # cannot accidentally replace this application's identity.
  def enforce_application_mail_identity
    identity = Foundation.runtime_config.mailer_from
    headers["From"] = identity
    headers["Reply-To"] = identity
  end
end
