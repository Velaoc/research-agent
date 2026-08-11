ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/billing_test_helper"
# foundation:module crm
require_relative "support/crm_test_helper" if File.exist?(File.expand_path("support/crm_test_helper.rb", __dir__))
# /foundation:module crm

# Drives OmniAuth in its test mode: the request phase never contacts a
# provider and instead redirects straight to the callback carrying the
# canned auth hash set by stub_oauth.
module OmniauthTestHelpers
  extend ActiveSupport::Concern

  included do
    teardown do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth.except!(:google_oauth2, :github)
    end
  end

  def stub_oauth(provider, uid:, email:)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: { email: email }
    )
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    private

    # Runs the block with the given ENV entries applied (nil deletes a key),
    # restoring the previous values afterwards. Used by the offline-preview
    # and mail-selection matrices.
    def with_env(entries)
      previous = entries.keys.index_with { |key| ENV[key] }
      previous_runtime = Foundation.runtime_config
      entries.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      if (entries.keys & Foundation::RuntimeConfig::RUNTIME_ENV_KEYS).any?
        Rails.configuration.x.runtime_config = Foundation::RuntimeConfig.new(
          environment: ENV,
          foundation: Rails.configuration.x.foundation,
          rails_environment: Rails.env
        )
      end
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      Rails.configuration.x.runtime_config = previous_runtime if previous_runtime
    end

    # Minitest 6 no longer bundles Object#stub. Keep network-bound tests
    # explicit by replacing one singleton method for the duration of a block.
    def with_stubbed_singleton_method(target, method_name, replacement)
      original = target.method(method_name)
      target.define_singleton_method(method_name, replacement)
      yield
    ensure
      target.define_singleton_method(method_name, original)
    end
  end
end

module ReauthenticationTestHelpers
  REAUTH_PASSWORD = "correct horse battery"

  private

  # Opens the Cap 1 trust window via the real password confirm endpoint.
  def grant_reauthentication!(password: REAUTH_PASSWORD)
    post reauthentication_path, params: { password: password }
  end
end

# foundation:module storefront
module StorefrontTestHelpers
  private

  def create_storefront_product(**attributes)
    suffix = SecureRandom.hex(4)
    Foundation::Storefront::Product.create!({
      name: "Digital product #{suffix}", slug: "digital-product-#{suffix}",
      sku: "DIGITAL-#{suffix.upcase}", description: "A downloadable test product.",
      price_cents: 1_299, currency: "USD", active: true,
      inventory_quantity: 20, position: 0
    }.merge(attributes))
  end

  def create_storefront_order(product: create_storefront_product, quantity: 1, email: "guest@example.com", user: nil)
    Foundation::Storefront::CreateOrder.call(
      cart: { product.id.to_s => quantity.to_s }, email: email, user: user,
      legal_assent: "1", ip: "192.0.2.10", user_agent: "Storefront test"
    )
  end
end

ActiveSupport::TestCase.include(StorefrontTestHelpers)
# /foundation:module storefront
ActionDispatch::IntegrationTest.include(ReauthenticationTestHelpers)
