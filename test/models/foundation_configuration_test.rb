require "test_helper"

class FoundationConfigurationTest < ActiveSupport::TestCase
  REQUIRED_KEYS = begin
    keys = %w[
      application_name
      logo_url
      brand_seed_color
      default_page_title
      default_page_description
      default_og_image_url
      social_links
      support_email
      legal_email
      domain
      healthcheck_disk_usage_percent_max
      healthcheck_memory_usage_percent_max
    ]
    # foundation:module storefront
    keys += %w[
      storefront_enabled
      storefront_fulfillment_mode
      storefront_commerce_legal_reviewed
      storefront_external_image_hosts
    ]
    # /foundation:module storefront
    keys.freeze
  end

  test "foundation config is loaded with indifferent access" do
    foundation = Rails.configuration.x.foundation

    assert_kind_of ActiveSupport::HashWithIndifferentAccess, foundation
    assert_equal foundation[:application_name], foundation["application_name"]
  end

  test "foundation config contains every required key" do
    foundation = Rails.configuration.x.foundation

    REQUIRED_KEYS.each do |key|
      assert foundation.key?(key), "expected config/foundation.yml to define #{key}"
    end
  end

  test "foundation config template defaults" do
    foundation = Rails.configuration.x.foundation

    assert_equal "Application", foundation[:application_name]
    assert_match(/\A#\h{6}\z/, foundation[:brand_seed_color])
    # foundation:module storefront
    assert_equal true, foundation[:storefront_enabled]
    assert_equal "digital", foundation[:storefront_fulfillment_mode]
    assert_equal false, foundation[:storefront_commerce_legal_reviewed]
    assert_equal [], foundation[:storefront_external_image_hosts]
    # /foundation:module storefront
    assert_equal 90, foundation[:healthcheck_disk_usage_percent_max]
    assert_equal 90, foundation[:healthcheck_memory_usage_percent_max]
  end
end
