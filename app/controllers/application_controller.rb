class ApplicationController < ActionController::Base
  include Foundation::Reauthentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # A failed (or missing) Turnstile response on a guarded form is almost
  # always a bot; for the rare human, send them back to retry the challenge.
  rescue_from RailsCloudflareTurnstile::Forbidden do
    redirect_back fallback_location: root_path,
      alert: "We could not verify you are human. Please complete the challenge and try again."
  end

  # Expose the session-persisted active workspace as Current.organization
  # for app code (SPEC M4.4). current_organization comes from the
  # organizations gem, which validates membership on every resolution.
  before_action :assign_current_attributes

  # Absolute URLs generated in a controller or view come from the validated
  # boot snapshot, exactly like mailer links. A spoofed or unexpected request
  # Host therefore cannot appear in a payment return URL, a redirect, or any
  # other link this application hands out.
  def default_url_options
    Foundation.runtime_config.url_options
  end

  private

  def assign_current_attributes
    Current.user = current_user
    Current.organization = current_organization
  end

  # The public invitation page parks the invitation token in the session
  # and sends existing users to sign in (SPEC M4.2); complete the join as
  # soon as they authenticate. Native shells hand off through /native/entry
  # so the web view can dismiss its auth stack (SPEC M14).
  def after_sign_in_path_for(resource)
    if hotwire_native_app? && resource.is_a?(User)
      return native_entry_path unless pending_invitation_acceptance_redirect_path_for(resource)
    end

    if resource.is_a?(User) && (path = pending_invitation_acceptance_redirect_path_for(resource))
      path
    else
      super
    end
  end
end
