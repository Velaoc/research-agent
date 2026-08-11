# Minimal settings page for linked sign-in providers (SPEC M3.3): connect
# starts a normal OmniAuth round-trip while signed in; disconnect removes an
# identity unless it is the account's only remaining way to sign in.
class Foundation::ConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_recent_reauthentication!, only: :destroy

  def show
    @identities = current_user.identities.order(:provider, :created_at)
  end

  def destroy
    identity = current_user.identities.find(params[:id])

    if current_user.removable_identity?(identity)
      identity.destroy!
      redirect_to settings_connections_path,
        notice: "#{Foundation::Oauth.label(identity.provider)} has been disconnected."
    else
      redirect_to settings_connections_path,
        alert: "That is currently your only way to sign in, so it cannot be disconnected. " \
               "Set a password (via password reset) or connect another provider first."
    end
  end
end
