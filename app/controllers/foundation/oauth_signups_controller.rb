# Interstitial legal-assent step for first-time OAuth users (SPEC M3.3).
# The callback controller parks the provider payload in the session and
# sends the visitor here; nothing is written to the database until they
# accept, and declining (or walking away for PENDING_TTL) leaves no trace.
class Foundation::OauthSignupsController < ApplicationController
  # Session slot holding the pending OAuth payload: provider, uid, email,
  # and an expiry timestamp. Deliberately excludes provider tokens.
  SESSION_KEY = "foundation_pending_oauth"
  PENDING_TTL = 30.minutes

  before_action :load_pending_oauth, only: [ :new, :create ]

  def new
    @user = User.new(email: @pending["email"])
  end

  def create
    @user = build_user

    if @user.save
      LegalAcceptance.record!(user: @user, request: request, context: "oauth_signup")
      session.delete(SESSION_KEY)
      sign_in(@user)

      # SPEC M4: an OAuth signup that started from an organization
      # invitation joins that workspace (the personal one was skipped in
      # build_user); the helper sets its own flash notice.
      if @user.skip_personal_organization &&
         (path = pending_invitation_acceptance_redirect_path_for(@user))
        redirect_to path
      else
        redirect_to root_path, notice: "Welcome! Your account is ready."
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  # Declining assent abandons the signup entirely.
  def destroy
    session.delete(SESSION_KEY)
    redirect_to new_user_session_path, notice: "Sign-up canceled. No account was created."
  end

  private

  def load_pending_oauth
    @pending = session[SESSION_KEY]
    return if pending_usable?

    session.delete(SESSION_KEY)
    redirect_to new_user_session_path,
      alert: "There is no sign-up in progress. Please start again."
  end

  def pending_usable?
    @pending.present? && Time.iso8601(@pending["expires_at"].to_s).future?
  rescue ArgumentError
    false
  end

  def build_user
    user = User.new(email: @pending["email"], legal_assent: params[:legal_assent])
    user.identities.build(provider: @pending["provider"], uid: @pending["uid"])
    # SPEC M4.1: an invited signup joins the inviting workspace instead of
    # getting a personal one (only when the invitation is for this address).
    user.skip_personal_organization =
      pending_organization_invitation&.for_email?(@pending["email"]) || false
    # The provider already verified this address (SPEC M3.3), so the account
    # starts confirmed and no confirmation email goes out.
    user.skip_confirmation!
    user
  end
end
