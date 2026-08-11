# frozen_string_literal: true

# Team workspaces (SPEC M4) via the organizations gem. Only overrides of the
# gem's defaults live here; the gem README documents the full option list.
Organizations.configure do |config|
  # Every fresh signup gets a personal workspace (SPEC M4.1), named after
  # the mailbox it registered with. Signups that arrive through an
  # organization invitation opt out per user via
  # User#skip_personal_organization and join the inviting workspace instead.
  config.always_create_personal_organization_for_each_user = true
  config.default_organization_name = lambda { |user|
    local_part = user.email.to_s.split("@").first
    local_part.present? ? "#{local_part}'s workspace" : "My workspace"
  }

  # Invitation mail goes through our own mailer (M2 mailer defaults) so the
  # emailed link carries a signed, expiring token (SPEC M4.2). The gem keeps
  # a random single-use token with a stored expiry behind the accept page.
  config.invitation_mailer = "Foundation::OrganizationInvitationMailer"
  config.invitation_expiry = 7.days

  # The public invitation-acceptance pages render inside the normal
  # application stack (layout helpers, Devise's current_user). Safe here:
  # our ApplicationController has no blanket authentication filter.
  config.public_controller = "ApplicationController"

  # SPEC M4 role contract: owner / admin / member. Role changes and
  # ownership transfer are owner-only; renaming, inviting, and removing
  # members are admin-and-up. The gem's built-in :viewer tier is left
  # without permissions and is never offered by the UI.
  config.roles do
    role :member do
      can :view_organization
      can :view_members
    end

    role :admin, inherits: :member do
      can :invite_members
      can :remove_members
      can :manage_settings
    end

    role :owner, inherits: :admin do
      can :edit_member_roles
      can :transfer_ownership
      can :delete_organization
    end
  end
end

# The organizations gem owns this model; attach the app-specific billing and
# entitlement behavior without copying or replacing the engine's model.
# Organization deletion lives on the engine controller (inherits host
# ApplicationController, so Cap 1 helpers are already available) — inject
# the destroy before_action once.
Rails.application.config.to_prepare do
  Organizations::Organization.include(Foundation::BillableOrganization) unless
    Organizations::Organization < Foundation::BillableOrganization

  if defined?(Organizations::OrganizationsController)
    unless Organizations::OrganizationsController._process_action_callbacks.any? { |cb|
      cb.filter == :require_recent_reauthentication! && cb.kind == :before
    }
      Organizations::OrganizationsController.before_action :require_recent_reauthentication!, only: :destroy
    end
  end
end
