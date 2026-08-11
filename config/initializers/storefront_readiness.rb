# frozen_string_literal: true

# Production processes fail at boot when the enabled storefront cannot safely
# accept verified payments. Asset precompilation remains secret-free under the
# Rails-generated SECRET_KEY_BASE_DUMMY contract.
Rails.application.config.after_initialize do
  if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"] != "1" && Foundation.storefront_enabled?
    result = Foundation::Storefront::Readiness.call
    raise "Storefront readiness failed: #{result.errors.join('; ')}" unless result.ready?
  end
end
