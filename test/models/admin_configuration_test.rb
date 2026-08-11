require "test_helper"

class AdminConfigurationTest < ActiveSupport::TestCase
  test "new users are never admins by default" do
    user = User.new
    assert_not_predicate user, :admin?
    assert_equal false, User.column_defaults.fetch("admin")
  end

  test "session retention and recurring sweep stay explicitly bounded" do
    assert_equal 5.minutes, Sessions.config.touch_every
    assert_equal 100, Sessions.config.max_sessions_per_user
    assert_equal 12.months, Sessions.config.events_retention

    recurring = YAML.safe_load_file(Rails.root.join("config/recurring.yml"))
    sweep = recurring.dig("production", "sessions_sweep")
    assert_equal "SessionsSweepJob", sweep.fetch("class")
    assert_equal "every day at 4am", sweep.fetch("schedule")
  end

  test "mission control uses the app admin controller and no second password" do
    assert_equal "Foundation::Admin::BaseController", MissionControl::Jobs.base_controller_class
    assert_not MissionControl::Jobs.http_basic_auth_enabled
    assert MissionControl::Jobs::ApplicationController < Foundation::Admin::BaseController
    assert MissionControl::Jobs::JobsHelper < Foundation::Admin::MissionControlJobsHelper
  end

  test "job argument filter redacts keyed secrets and every positional value" do
    data = {
      "job_class" => "SensitiveJob",
      "arguments" => [
        "positional-secret",
        { "account_id" => 17, "password" => "hash-secret", "nested" => { "token" => "nested-secret" } }
      ]
    }

    filtered = Foundation::Admin::JobDataFilter.raw_data(data)
    serialized = JSON.generate(filtered)

    assert_equal Foundation::Admin::JobDataFilter::FILTERED, filtered.fetch("arguments").first
    assert_equal 17, filtered.dig("arguments", 1, "account_id")
    assert_equal "[FILTERED]", filtered.dig("arguments", 1, "password")
    assert_equal "[FILTERED]", filtered.dig("arguments", 1, "nested", "token")
    assert_not_includes serialized, "positional-secret"
    assert_not_includes serialized, "hash-secret"
    assert_not_includes serialized, "nested-secret"
  end
end
