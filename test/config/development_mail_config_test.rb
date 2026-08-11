# frozen_string_literal: true

require "test_helper"

class DevelopmentMailConfigTest < ActiveSupport::TestCase
  # A fresh checkout has no mail server on localhost:25. If development falls
  # back to :smtp, the very first signup crashes with ECONNREFUSED when Devise
  # sends its confirmation message — found by hand-testing, not by the suite,
  # because only the test environment was ever exercised. Development must
  # fall back to the in-memory adapter, while still honoring deploy-time SMTP
  # so a local mail catcher can be pointed at with SMTP_ADDRESS.
  test "development falls back to the in-memory mail adapter" do
    source = Rails.root.join("config/environments/development.rb").read

    assert_includes source, "mail_delivery_method(provider: :test)",
      "development must not fall back to :smtp — a fresh machine has no local mail server"
  end

  test "the runtime precedence keeps deploy-time SMTP ahead of the development fallback" do
    with_env("SMTP_ADDRESS" => "mailcatcher.local", "SMTP_PORT" => "1025") do
      config = Foundation::RuntimeConfig.new(
        environment: ENV,
        foundation: Rails.configuration.x.foundation,
        rails_environment: "development"
      )
      assert_equal :smtp, config.mail_delivery_method(provider: :test)
    end

    with_env("SMTP_ADDRESS" => nil) do
      config = Foundation::RuntimeConfig.new(
        environment: ENV,
        foundation: Rails.configuration.x.foundation,
        rails_environment: "development"
      )
      assert_equal :test, config.mail_delivery_method(provider: :test)
    end
  end
end
