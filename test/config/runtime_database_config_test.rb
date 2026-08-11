require "test_helper"
require "erb"
require "yaml"

class RuntimeDatabaseConfigTest < ActiveSupport::TestCase
  test "production uses one primary configuration when only DATABASE_URL is supplied" do
    configs = production_config(
      "DATABASE_URL" => "postgresql:///foundation_primary",
      "CACHE_DATABASE_URL" => nil,
      "QUEUE_DATABASE_URL" => nil,
      "CABLE_DATABASE_URL" => nil
    )

    assert_equal [ "primary" ], configs.keys
    assert_equal "postgresql:///foundation_primary", configs.dig("primary", "url")
  end

  test "explicit adapter database URLs add only their named configurations" do
    configs = production_config(
      "DATABASE_URL" => "postgresql:///foundation_primary",
      "CACHE_DATABASE_URL" => "postgresql:///foundation_cache",
      "QUEUE_DATABASE_URL" => nil,
      "CABLE_DATABASE_URL" => "postgresql:///foundation_cable"
    )

    assert_equal %w[cable cache primary], configs.keys.sort
    assert_equal "postgresql:///foundation_cache", configs.dig("cache", "url")
    assert_equal "postgresql:///foundation_cable", configs.dig("cable", "url")
  end

  test "primary schema contains queue cache and cable tables" do
    schema = Rails.root.join("db/schema.rb").read

    assert_includes schema, 'create_table "solid_queue_jobs"'
    assert_includes schema, 'create_table "solid_cache_entries"'
    assert_includes schema, 'create_table "solid_cable_messages"'
  end

  test "Puma queue plugin uses the same exact enabled value" do
    puma_config = Rails.root.join("config/puma.rb").read

    assert_includes puma_config, 'ENV["SOLID_QUEUE_IN_PUMA"] == "1"'
  end

  private

  def production_config(environment)
    with_env(environment) do
      contents = ERB.new(Rails.root.join("config/database.yml").read).result
      YAML.safe_load(contents, aliases: true).fetch("production")
    end
  end
end
