class User < ApplicationRecord
  # :timeoutable is deliberately not enabled: sessions are long-lived via
  # :rememberable, and an idle timeout on top of remember-me cookies mostly
  # produces surprise logouts. Enable it here if your product needs one.
  # :omniauthable draws request/callback routes for whichever providers
  # config/initializers/devise.rb registered from the environment; with no
  # OAuth credentials present the app still boots and simply has none.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :omniauthable

  has_many :legal_acceptances, dependent: :destroy
  has_many :identities, dependent: :destroy
  # foundation:module storefront
  has_many :storefront_orders,
    class_name: "Foundation::Storefront::Order",
    dependent: :nullify,
    inverse_of: :user
  # /foundation:module storefront
  has_sessions

  # Team workspaces (SPEC M4). A personal organization is created right
  # after signup (config/initializers/organizations.rb); signups that come
  # in through an organization invitation set skip_personal_organization so
  # they join the inviting workspace instead of getting one of their own.
  has_organizations
  attr_accessor :skip_personal_organization

  def should_create_personal_organization?
    return false if skip_personal_organization

    super
  end

  # Virtual attribute backing the signup assent checkbox. Registration posts
  # "1" when the box is ticked; anything else (including a missing param —
  # hence allow_nil: false) fails validation, so assent is enforced
  # server-side and not just by the form markup. Non-registration creation
  # paths (console, seeds, future OAuth interstitial) must set it explicitly,
  # which keeps "an account exists" equivalent to "assent was given".
  attr_accessor :legal_assent
  validates :legal_assent, acceptance: { allow_nil: false }, on: :create

  # Refuse throwaway mailboxes at registration (SPEC M2.3). Checked only on
  # create: a domain later added to the blocklist must not brick the account
  # that legitimately registered before it was listed.
  validates :email, nondisposable: true, on: :create

  before_create :skip_confirmation_for_offline_preview

  # Whether this account can sign in with a password at all. OAuth-created
  # accounts have none (encrypted_password stays blank) until the user sets
  # one through the password-reset flow.
  def password_configured?
    encrypted_password.present?
  end

  # SPEC M3.3: an identity may be disconnected only while some other way to
  # sign in remains — a password, or at least one other identity.
  def removable_identity?(identity)
    password_configured? || identities.where.not(id: identity.id).exists?
  end

  # Devise's :validatable demands a password on create. An OAuth signup
  # builds the user together with its first identity and no password at all
  # (the provider is the sign-in method), so relax the requirement for
  # exactly that case. A password that IS supplied — on any path — keeps
  # every stock validation.
  def password_required?
    oauth_signup = new_record? && identities.any? &&
      password.blank? && password_confirmation.blank?
    return false if oauth_signup

    super
  end

  private

  # SPEC M2.5 / M9.3: a hosted preview without an SMTP relay cannot deliver
  # the confirmation email, so accounts are confirmed immediately there.
  # Everywhere else the normal Devise confirmable flow applies.
  def skip_confirmation_for_offline_preview
    skip_confirmation! if Foundation.offline_preview?
  end
end
