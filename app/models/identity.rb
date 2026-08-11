# A linked OAuth account (SPEC M3.2): one row per external (provider, uid)
# pair, owned by exactly one user. A user may hold any number of identities,
# and an external account can never be attached to two users at once —
# uniqueness is enforced both here and by a database index.
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
end
