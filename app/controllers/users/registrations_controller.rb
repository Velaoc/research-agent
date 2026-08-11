class Users::RegistrationsController < Devise::RegistrationsController
  # Cloudflare Turnstile guards account creation (SPEC M2.2). The helper is
  # a no-op wherever Turnstile is disabled (test) or unconfigured.
  before_action :validate_cloudflare_turnstile, only: :create

  before_action :configure_sign_up_params, only: :create
  before_action :require_recent_reauthentication!, only: :update

  # On top of Devise's create, persist the legal assent the user just gave
  # (SPEC M2.4), and — when the signup arrived through an organization
  # invitation — join the inviting workspace (SPEC M4.1/M4.2). The personal
  # organization was already skipped for that case in build_resource.
  def create
    super do |user|
      next unless user.persisted?

      LegalAcceptance.record!(user: user, request: request, context: "signup")
      accept_pending_organization_invitation!(user) if user.skip_personal_organization
    end
  end

  def update
    super do |user|
      next unless user.errors.empty?

      clear_reauthentication_window! if user.saved_change_to_encrypted_password?
    end
  end

  # SPEC M4.3: a workspace must not silently lose its owner. Deleting an
  # account destroys workspaces only this user occupies (the personal one),
  # and is refused while the user still owns a workspace with other members.
  def destroy
    shared = resource.owned_organizations.detect do |organization|
      organization.memberships.where.not(user_id: resource.id).exists?
    end

    if shared
      redirect_to edit_user_registration_path,
        alert: "You still own #{shared.name}, which has other members. " \
               "Transfer ownership or remove its members before deleting your account."
    else
      resource.owned_organizations.each(&:destroy!)
      super
    end
  end

  private

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :legal_assent ])
  end

  # A registration that started from an organization invitation (token
  # parked in the session by the public accept page) skips the personal
  # organization — it joins the inviting one right after save. Only an
  # email matching the invitation counts; any other address could never
  # accept that invitation and gets the normal personal workspace.
  def build_resource(hash = {})
    super
    resource.skip_personal_organization =
      pending_organization_invitation&.for_email?(resource.email) || false
  end
end
