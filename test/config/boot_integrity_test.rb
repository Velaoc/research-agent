require "test_helper"

class BootIntegrityTest < ActiveSupport::TestCase
  test "application eager-loads without Zeitwerk violations" do
    assert_nothing_raised do
      Rails.application.eager_load!
    end
  end
end
