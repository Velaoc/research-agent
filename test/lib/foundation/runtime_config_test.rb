require "test_helper"

class FoundationRuntimeConfigTest < ActiveSupport::TestCase
  IDENTITY = {
    domain: "foundation.example",
    support_email: "Support <support@foundation.example>"
  }.freeze

  test "configuration and returned values are immutable snapshots" do
    environment = {
      "APP_HOST" => +"preview.holodex.test",
      "VELA_HOLODEX_PREVIEW" => "1",
      "SMTP_ADDRESS" => +"holodex",
      "SMTP_PASSWORD" => +"secret",
      "SMTP_USERNAME" => +"preview"
    }
    config = runtime(environment)
    environment["APP_HOST"].replace("attacker.example")
    environment["SMTP_PASSWORD"].replace("changed")

    assert_predicate config, :frozen?
    assert_predicate config.smtp_settings, :frozen?
    assert_predicate config.smtp_settings[:password], :frozen?
    assert_predicate config.url_options, :frozen?
    assert_equal "https://preview.holodex.test", config.canonical_origin
    assert_equal "secret", config.smtp_settings[:password]
  end

  test "preview and queue flags accept only exact binary values" do
    assert_not runtime.preview?
    assert_not runtime({ "VELA_HOLODEX_PREVIEW" => "0" }).preview?
    assert runtime({ "VELA_HOLODEX_PREVIEW" => "1" }).preview?
    assert_not runtime({ "SOLID_QUEUE_IN_PUMA" => "0" }).solid_queue_in_puma?
    assert runtime({ "SOLID_QUEUE_IN_PUMA" => "1" }).solid_queue_in_puma?

    %w[true false yes 01].each do |value|
      assert_raises(Foundation::RuntimeConfig::Invalid) do
        runtime({ "VELA_HOLODEX_PREVIEW" => value })
      end
      assert_raises(Foundation::RuntimeConfig::Invalid) do
        runtime({ "SOLID_QUEUE_IN_PUMA" => value })
      end
    end
  end

  test "canonical origin accepts bare Holodex host and absolute origins" do
    preview = runtime({ "APP_HOST" => "daily.holodex.test", "VELA_HOLODEX_PREVIEW" => "1" })
    production = runtime({ "APP_HOST" => "https://shop.foundation.example:8443" }, rails_environment: :production)
    bare = runtime({ "APP_HOST" => "devbox.test:3100" })
    fallback = runtime

    assert_equal "https://daily.holodex.test", preview.canonical_origin
    assert_equal({ host: "daily.holodex.test", protocol: "https://" }, preview.url_options)
    assert_equal "https://shop.foundation.example:8443", production.canonical_origin
    assert_equal 8443, production.url_options[:port]
    assert_equal "https://devbox.test:3100", bare.canonical_origin
    assert_equal "https://foundation.example", fallback.canonical_origin
  end

  # Plaintext links are safe only where the traffic never leaves the machine,
  # so locality of the host decides the scheme rather than the Rails
  # environment: a routable host is always HTTPS, everywhere.
  test "plain HTTP is confined to loopback development hosts" do
    {
      "localhost" => "http://localhost",
      "localhost:3000" => "http://localhost:3000",
      "http://localhost:3000" => "http://localhost:3000",
      "app.localhost:3000" => "http://app.localhost:3000",
      "127.0.0.1:3000" => "http://127.0.0.1:3000",
      "127.9.9.9" => "http://127.9.9.9",
      "0.0.0.0:3000" => "http://0.0.0.0:3000",
      "[::1]:3000" => "http://[::1]:3000"
    }.each do |configured, expected|
      assert_equal expected, runtime({ "APP_HOST" => configured }).canonical_origin, configured
    end

    # A routable host never downgrades, whether it is bare or explicit.
    assert_equal "https://devbox.test", runtime({ "APP_HOST" => "devbox.test" }).canonical_origin
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "APP_HOST" => "http://devbox.test" })
    end

    # Preview and production are published deployments: HTTPS regardless.
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "APP_HOST" => "localhost:3000", "VELA_HOLODEX_PREVIEW" => "1" })
    end
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "APP_HOST" => "localhost:3000" }, rails_environment: :production)
    end
  end

  test "development without APP_HOST keeps generated links on the machine" do
    development = runtime({}, rails_environment: :development)

    assert_equal "http://localhost:3000", development.canonical_origin
    assert_equal({ host: "localhost", protocol: "http://", port: 3000 }, development.url_options)
    assert_not development.app_host_configured?

    # Every deployed environment still falls back to the foundation domain.
    assert_equal "https://foundation.example", runtime({}, rails_environment: :production).canonical_origin
  end

  # An injected APP_HOST must not be able to move Stripe return URLs or
  # emailed links off the product's own domain in production.
  test "production APP_HOST is pinned to the configured domain" do
    assert_equal "https://foundation.example",
      runtime({ "APP_HOST" => "https://foundation.example" }, rails_environment: :production).canonical_origin
    assert_equal "https://www.foundation.example",
      runtime({ "APP_HOST" => "https://www.foundation.example" }, rails_environment: :production).canonical_origin

    [ "https://other.example", "https://foundation.example.attacker.test", "https://notfoundation.example" ].each do |host|
      assert_raises(Foundation::RuntimeConfig::Invalid, host) do
        runtime({ "APP_HOST" => host }, rails_environment: :production)
      end
    end

    # A hosted preview is assigned its hostname at run time and can never
    # match the template's own domain, so preview is deliberately exempt.
    preview = runtime(
      { "APP_HOST" => "https://slug.demo.holodex.test", "VELA_HOLODEX_PREVIEW" => "1" },
      rails_environment: :production
    )
    assert_equal "https://slug.demo.holodex.test", preview.canonical_origin
  end

  test "canonical origin rejects non-origins and plaintext hosted URLs" do
    invalid = [
      "https://user:password@app.example",
      "https://app.example/",
      "https://app.example/path",
      "https://app.example?query=1",
      "https://app.example#fragment",
      "https://bad_host.example",
      "https://app.example\nX-Injected: yes"
    ]
    invalid.each do |host|
      assert_raises(Foundation::RuntimeConfig::Invalid, host.inspect) do
        runtime({ "APP_HOST" => host }, rails_environment: :production)
      end
    end

    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "APP_HOST" => "http://preview.example", "VELA_HOLODEX_PREVIEW" => "1" })
    end
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "APP_HOST" => "http://production.example" }, rails_environment: :production)
    end
  end

  test "SMTP selection and Holodex settings are provider neutral" do
    relay = runtime({
      "SMTP_ADDRESS" => "holodex",
      "SMTP_PORT" => "2525",
      "SMTP_ENABLE_STARTTLS_AUTO" => "false",
      "MAILER_FROM" => "Holodex <noreply@daily.holodex.test>"
    })
    offline = runtime({ "VELA_HOLODEX_PREVIEW" => "1" })
    provider = runtime

    assert_equal :smtp, relay.mail_delivery_method(provider: :custom_provider)
    assert_equal({
      address: "holodex", port: 2525, enable_starttls_auto: false,
      open_timeout: 5, read_timeout: 5
    }, relay.smtp_settings)
    assert_equal "Holodex <noreply@daily.holodex.test>", relay.mailer_from
    assert_equal :test, offline.mail_delivery_method(provider: :custom_provider)
    assert_predicate offline, :offline_preview?
    assert_not offline.raise_delivery_errors?
    assert_equal :custom_provider, provider.mail_delivery_method(provider: :custom_provider)
    assert provider.raise_delivery_errors?
  end

  test "SMTP authentication starttls and port parsing fail closed" do
    authenticated = runtime({
      "SMTP_ADDRESS" => "smtp.example",
      "SMTP_USERNAME" => "operator",
      "SMTP_PASSWORD" => "secret"
    })
    assert_equal 587, authenticated.smtp_settings[:port]
    assert_equal :plain, authenticated.smtp_settings[:authentication]
    assert_equal true, authenticated.smtp_settings[:enable_starttls_auto]

    [ "0", "65536", "12.5", "" ].each do |port|
      assert_raises(Foundation::RuntimeConfig::Invalid) do
        runtime({ "SMTP_ADDRESS" => "smtp.example", "SMTP_PORT" => port })
      end
    end
    [ "1", "TRUE", "" ].each do |starttls|
      assert_raises(Foundation::RuntimeConfig::Invalid) do
        runtime({ "SMTP_ADDRESS" => "smtp.example", "SMTP_ENABLE_STARTTLS_AUTO" => starttls })
      end
    end
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "SMTP_ADDRESS" => "smtp.example", "SMTP_USERNAME" => "operator" })
    end
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "SMTP_PORT" => "2525" })
    end
  end

  test "MAILER_FROM is exactly one mailbox without header injection" do
    assert_equal "Support <support@foundation.example>", runtime.mailer_from

    [
      "first@example.com, second@example.com",
      "Sender <sender@example.com>\r\nBcc: victim@example.com",
      "not-a-mailbox"
    ].each do |mailbox|
      assert_raises(Foundation::RuntimeConfig::Invalid) do
        runtime({ "MAILER_FROM" => mailbox })
      end
    end
  end

  test "preview storage and optional database roles are explicit" do
    preview = runtime({
      "VELA_HOLODEX_PREVIEW" => "1",
      "ACTIVE_STORAGE_SERVICE" => "amazon",
      "QUEUE_DATABASE_URL" => "postgresql:///queue"
    }, rails_environment: :production)
    production = runtime({ "ACTIVE_STORAGE_SERVICE" => "amazon" }, rails_environment: :production)
    unsafe = runtime({}, rails_environment: :production)

    assert_equal :local, preview.active_storage_service
    assert_equal "local preview disk", preview.storage_mode
    assert preview.production_storage_configured?
    assert_equal :queue, preview.database_role(:queue)
    assert_equal :primary, preview.database_role(:cache)
    assert_equal :amazon, production.active_storage_service
    assert production.production_storage_configured?
    assert_equal :local, unsafe.active_storage_service
    assert_not unsafe.production_storage_configured?
  end

  test "preview payment mode defaults to simulator and permits only test Stripe opt in" do
    simulator = runtime({ "VELA_HOLODEX_PREVIEW" => "1" })
    stripe = runtime({
      "VELA_HOLODEX_PREVIEW" => "1",
      "STOREFRONT_PREVIEW_PAYMENT_MODE" => "stripe"
    })

    assert_predicate simulator, :simulator?
    assert_not simulator.preview_stripe?
    assert_predicate stripe, :preview_stripe?
    assert_raises(Foundation::RuntimeConfig::Invalid) do
      runtime({ "VELA_HOLODEX_PREVIEW" => "1", "STOREFRONT_PREVIEW_PAYMENT_MODE" => "live" })
    end
  end

  test "production request hosts cover the product domain; preview allows only APP_HOST" do
    production = runtime({ "APP_HOST" => "https://shop.foundation.example" }, rails_environment: :production)
    assert_equal [ ".foundation.example" ],
      production.allowed_request_hosts(foundation_domain: "foundation.example")

    preview = runtime(
      { "APP_HOST" => "https://slug.demo.holodex.test", "VELA_HOLODEX_PREVIEW" => "1" },
      rails_environment: :production
    )
    assert_equal [ "slug.demo.holodex.test" ],
      preview.allowed_request_hosts(foundation_domain: "foundation.example")
  end

  private

  def runtime(environment = {}, rails_environment: :test)
    Foundation::RuntimeConfig.new(
      environment: environment,
      foundation: IDENTITY,
      rails_environment: rails_environment
    )
  end
end
