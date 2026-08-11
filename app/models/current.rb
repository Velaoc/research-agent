# Request-local context (reset around every request by
# ActiveSupport::CurrentAttributes). Current.organization is the signed-in
# user's active workspace — persisted per session by the organizations gem
# and assigned in ApplicationController — so app code can scope queries
# with Current.organization without threading it through call sites
# (SPEC M4.4).
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization
end
