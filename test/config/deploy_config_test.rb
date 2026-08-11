# frozen_string_literal: true

require "test_helper"
require "yaml"

# The self-host path is config, not runtime code. These assertions keep the
# Kamal template honest against Foundation::RuntimeConfig so a deploy cannot
# silently omit a boot-required variable or reintroduce the hosted-preview flag.
class DeployConfigTest < ActiveSupport::TestCase
  DEPLOY = Rails.root.join("config/deploy.yml")
  SECRETS = Rails.root.join(".kamal/secrets")
  STORAGE = Rails.root.join("config/storage.yml")
  PRODUCTION = Rails.root.join("config/environments/production.rb")

  test "kamal deploy config is present and parses" do
    assert_path_exists DEPLOY
    assert_path_exists SECRETS
    config = yaml_without_erb(DEPLOY)

    assert_equal "vela-foundation", config.fetch("service")
    assert config.dig("proxy", "ssl")
    assert_equal "/up", config.dig("proxy", "healthcheck", "path")
    assert_equal "/rails/public/assets", config["asset_path"]
  end

  test "deploy env satisfies the runtime contract without hosted preview" do
    config = yaml_without_erb(DEPLOY)
    clear = config.fetch("env").fetch("clear")
    secret = config.fetch("env").fetch("secret")

    assert_equal "1", clear.fetch("SOLID_QUEUE_IN_PUMA").to_s,
      "RuntimeConfig accepts only exact 1/0 for SOLID_QUEUE_IN_PUMA"
    assert clear.key?("APP_HOST")
    assert_equal "amazon", clear.fetch("ACTIVE_STORAGE_SERVICE")

    %w[RAILS_MASTER_KEY DATABASE_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY].each do |key|
      assert_includes secret, key
    end

    # Hosted preview is injected by Holodex, never by the self-host template.
    assert_not clear.key?("VELA_HOLODEX_PREVIEW")
    assert_not_includes secret, "VELA_HOLODEX_PREVIEW"
    secrets_text = SECRETS.read
    assert_not_includes secrets_text.lines.grep_v(/^\s*#/).join, "VELA_HOLODEX_PREVIEW"
    assert_includes secrets_text, "RAILS_MASTER_KEY="
    assert_includes secrets_text, "DATABASE_URL="
  end

  test "production storage and SSL probe wiring match the deploy path" do
    storage = yaml_without_erb(STORAGE)
    assert_equal "S3", storage.dig("amazon", "service")

    production = PRODUCTION.read
    assert_includes production, "Foundation::RuntimeConfig::HEALTH_PROBE_PATHS"
    assert_includes production, "config.ssl_options"
    assert_includes production, "config.force_ssl = true"
    assert_includes production, "config.assume_ssl = true"
  end

  private

  # deploy.yml and storage.yml may contain ERB; strip tags so Psych can load
  # the static structure the operator edits.
  def yaml_without_erb(path)
    cleaned = path.read.gsub(/<%.*?%>/m, "")
    YAML.safe_load(cleaned, permitted_classes: [ Symbol ], aliases: true)
  end
end
