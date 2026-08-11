# frozen_string_literal: true

class Foundation::DevicesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_recent_reauthentication!, only: %i[destroy others]

  def index
    @sessions = current_user.sessions.live.by_recency.to_a
    current = Sessions.current(request)
    if current && @sessions.include?(current)
      @sessions.delete(current)
      @sessions.unshift(current)
    end
    @current_session = current
  end

  def destroy
    row = current_user.sessions.live.find_by(id: params[:id])
    unless row
      head :not_found
      return
    end

    if row.current?(request)
      redirect_to settings_sessions_root_path,
        alert: "You cannot revoke the device you are using. Sign out instead."
      return
    end

    row.revoke!(reason: :user_revoked, by: current_user)
    redirect_to settings_sessions_root_path, notice: "Signed out that device.", status: :see_other
  end

  def others
    current_user.revoke_other_sessions!(
      current: Sessions.current(request),
      by: current_user
    )
    redirect_to settings_sessions_root_path,
      notice: "Signed out of all other devices.",
      status: :see_other
  end
end
