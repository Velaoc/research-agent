# frozen_string_literal: true

require "test_helper"

class ReauthenticationHelpersTest < ActiveSupport::TestCase
  test "safe_return_path rejects blank and off-origin targets" do
    default = "/settings/sessions"

    assert_equal default, Foundation::Reauthentication.safe_return_path(nil, default: default)
    assert_equal default, Foundation::Reauthentication.safe_return_path("", default: default)
    assert_equal default, Foundation::Reauthentication.safe_return_path("https://evil.example/phish", default: default)
    assert_equal default, Foundation::Reauthentication.safe_return_path("//evil.example", default: default)
    assert_equal default, Foundation::Reauthentication.safe_return_path("/\\evil", default: default)
    assert_equal default, Foundation::Reauthentication.safe_return_path("javascript:alert(1)", default: default)
    assert_equal default, Foundation::Reauthentication.safe_return_path("/unknown-prefix", default: default)
  end

  test "safe_return_path accepts path-absolute allowed prefixes" do
    default = "/settings/sessions"

    assert_equal "/billing", Foundation::Reauthentication.safe_return_path("/billing", default: default)
    assert_equal "/settings/connections",
      Foundation::Reauthentication.safe_return_path("/settings/connections", default: default)
    assert_equal "/organizations/1",
      Foundation::Reauthentication.safe_return_path("/organizations/1", default: default)
    assert_equal "/admin/dashboard",
      Foundation::Reauthentication.safe_return_path("/admin/dashboard", default: default)
  end

  test "safe_return_path accepts same-origin absolute URLs as path only" do
    default = "/settings/sessions"
    origin = Foundation.runtime_config.canonical_origin
    path = Foundation::Reauthentication.safe_return_path("#{origin}/billing", default: default)
    assert_equal "/billing", path
  end

  test "open_window? fails closed on blank garbage and past values" do
    assert_not Foundation::Reauthentication.open_window?(nil)
    assert_not Foundation::Reauthentication.open_window?("")
    assert_not Foundation::Reauthentication.open_window?("not-a-time")
    assert_not Foundation::Reauthentication.open_window?(1.minute.ago)
    assert Foundation::Reauthentication.open_window?(5.minutes.from_now)
    assert Foundation::Reauthentication.open_window?(5.minutes.from_now.iso8601)
  end

  test "window constant is fifteen minutes" do
    assert_equal 15.minutes, Foundation::Reauthentication::WINDOW
  end
end
