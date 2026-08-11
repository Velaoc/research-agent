require "test_helper"

# SPEC M2.5 / M9.3: the offline-preview predicate that gates auto-confirmation
# (and, in M9, mail delivery selection). The full matrix, in one place.
class FoundationTest < ActiveSupport::TestCase
  test "offline_preview? is true only for preview mode without an SMTP relay" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "SMTP_ADDRESS" => nil) do
      assert Foundation.offline_preview?
    end
  end

  test "offline_preview? is false in preview mode when an SMTP relay is configured" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "SMTP_ADDRESS" => "smtp.example.com") do
      assert_not Foundation.offline_preview?
    end
  end

  test "offline_preview? treats an empty SMTP_ADDRESS as no relay" do
    with_env("VELA_HOLODEX_PREVIEW" => "1", "SMTP_ADDRESS" => "") do
      assert Foundation.offline_preview?, "an empty SMTP_ADDRESS counts as no relay"
    end
  end

  test "offline_preview? is false outside preview mode regardless of SMTP" do
    with_env("VELA_HOLODEX_PREVIEW" => nil, "SMTP_ADDRESS" => nil) do
      assert_not Foundation.offline_preview?
    end

    with_env("VELA_HOLODEX_PREVIEW" => nil, "SMTP_ADDRESS" => "smtp.example.com") do
      assert_not Foundation.offline_preview?
    end
  end

  test "offline_preview? rejects a malformed preview flag" do
    assert_raises Foundation::RuntimeConfig::Invalid do
      with_env("VELA_HOLODEX_PREVIEW" => "true", "SMTP_ADDRESS" => nil) do
        flunk "a malformed flag must prevent the runtime snapshot"
      end
    end
  end
end
