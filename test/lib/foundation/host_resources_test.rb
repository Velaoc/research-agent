# frozen_string_literal: true

require "test_helper"

class Foundation::HostResourcesTest < ActiveSupport::TestCase
  test "disk usage returns a percent or nil without raising" do
    usage = Foundation::HostResources.disk_usage_percent
    assert usage.nil? || (usage.is_a?(Integer) && usage.between?(0, 100))
  end

  test "memory usage returns a percent or nil without raising" do
    usage = Foundation::HostResources.memory_usage_percent
    assert usage.nil? || (usage.is_a?(Integer) && usage.between?(0, 100))
  end

  test "disk usage degrades when df output is unusable" do
    original = Foundation::HostResources.method(:`)
    Foundation::HostResources.define_singleton_method(:`) { |_cmd| "" }
    assert_nil Foundation::HostResources.disk_usage_percent
  ensure
    Foundation::HostResources.define_singleton_method(:`, original)
  end
end
