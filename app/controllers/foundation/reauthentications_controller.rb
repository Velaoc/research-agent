# frozen_string_literal: true

class Foundation::ReauthenticationsController < ApplicationController
  before_action :authenticate_user!

  def new
    stash_return_to_from_params
    @linked_providers = linked_oauth_providers
  end

  def create
    stash_return_to_from_params
    enforce_rate_limit! or return

    unless current_user.password_configured?
      Foundation::Reauthentication::Audit.write(
        outcome: :denied_no_password,
        actor: current_user,
        request: request
      )
      redirect_to new_reauthentication_path,
        alert: "#{Foundation::Reauthentication::GENERIC_FAILURE} Set a password first, or confirm with a linked provider."
      return
    end

    if current_user.valid_password?(params[:password].to_s)
      open_window_and_redirect!(outcome: :granted)
    else
      Foundation::Reauthentication::Audit.write(
        outcome: :denied,
        actor: current_user,
        request: request
      )
      redirect_to new_reauthentication_path, alert: Foundation::Reauthentication::GENERIC_FAILURE
    end
  end

  # Start an OAuth step-up round-trip through an already-linked provider.
  # Only linked identities may open the window; linking mid-flow never grants.
  def oauth
    stash_return_to_from_params
    provider = params[:provider].to_s
    enforce_rate_limit! or return

    unless linked_oauth_providers.include?(provider)
      Foundation::Reauthentication::Audit.write(
        outcome: :denied_unlinked_provider,
        actor: current_user,
        request: request,
        details: { provider: provider }
      )
      redirect_to new_reauthentication_path, alert: Foundation::Reauthentication::GENERIC_FAILURE
      return
    end

    session[Foundation::Reauthentication::SESSION_OAUTH_KEY] = {
      "provider" => provider,
      "user_id" => current_user.id,
      "return_to" => session[Foundation::Reauthentication::SESSION_RETURN_KEY],
      "started_at" => Time.current.iso8601
    }

    # OmniAuth authorize is POST-only (CSRF protection). Render a same-origin
    # auto-submit form rather than redirecting with GET.
    @provider = provider
    @authorize_path = omniauth_authorize_path(
      :user,
      provider,
      Foundation::Reauthentication.oauth_prompt_params(provider)
    )
    render :oauth_passthrough, status: :ok
  end

  private

  def stash_return_to_from_params
    candidate = params[:return_to].presence || session[Foundation::Reauthentication::SESSION_RETURN_KEY]
    session[Foundation::Reauthentication::SESSION_RETURN_KEY] =
      Foundation::Reauthentication.safe_return_path(
        candidate,
        default: settings_sessions_root_path
      )
  end

  def enforce_rate_limit!
    Foundation::Reauthentication::RateLimit.check!(
      account_id: current_user.id,
      ip: request.remote_ip
    )
    true
  rescue Foundation::Reauthentication::RateLimit::Exceeded
    Foundation::Reauthentication::Audit.write(
      outcome: :rate_limited,
      actor: current_user,
      request: request
    )
    redirect_to new_reauthentication_path, alert: Foundation::Reauthentication::GENERIC_FAILURE
    false
  end

  def open_window_and_redirect!(outcome:)
    grant_reauthentication_window!
    Foundation::Reauthentication::Audit.write(
      outcome: outcome,
      actor: current_user,
      request: request
    )
    path = consume_reauthentication_return_to(fallback: settings_sessions_root_path)
    redirect_to path, notice: "Identity confirmed. You can continue for a short time."
  end

  def linked_oauth_providers
    current_user.identities.distinct.pluck(:provider).sort
  end
end
