require "test_helper"

# The marketing home page is root only when the storefront runtime flag is
# off (or the module was omitted at generation). Flip the flag and reload
# routes so the default tree can still assert markup without depending on
# generation-time omission.
class HomePageTest < ActionDispatch::IntegrationTest
  setup do
    @foundation = Rails.configuration.x.foundation
    @storefront_flag = %w[storefront enabled].join("_").to_sym
    @previous_storefront = @foundation[@storefront_flag]
    @foundation[@storefront_flag] = false
    Rails.application.reload_routes!
  end

  teardown do
    @foundation[@storefront_flag] = @previous_storefront if @storefront_flag
    Rails.application.reload_routes!
  end

  test "home page always describes core foundation capabilities" do
    get root_path

    assert_response :success
    assert_select "h1"
    assert_select "[data-capability=accounts]"
    assert_select "[data-capability=organizations]"
    assert_select "[data-capability=billing]"
    assert_select "[data-capability=design]"
    assert_select "[data-capability=security]"
    assert_select "[data-capability=native]"
    assert_select ".md-pricing-grid .md-price-card", count: PricingPlans.plans.size
    assert_select "a[href='#{pricing_path}']", minimum: 1
  end

  test "home page reflects storefront module availability" do
    get root_path
    assert_response :success

    if Foundation.module_available?("storefront")
      assert_select "[data-module=storefront]", count: 1
    else
      assert_select "[data-module=storefront]", count: 0
    end

    with_stubbed_singleton_method(Foundation, :module_available?, lambda { |name, root: Rails.root|
      return false if name.to_s == "storefront"

      Foundation::Modules.available?(name, root: root)
    }) do
      get root_path
      assert_response :success
      assert_select "[data-module=storefront]", count: 0
      assert_select "[data-capability=accounts]"
    end
  end

  test "home page reflects crm module availability" do
    get root_path
    assert_response :success

    if Foundation.module_available?("crm")
      assert_select "[data-module=crm]", count: 1
    else
      assert_select "[data-module=crm]", count: 0
    end

    with_stubbed_singleton_method(Foundation, :module_available?, lambda { |name, root: Rails.root|
      return false if name.to_s == "crm"

      Foundation::Modules.available?(name, root: root)
    }) do
      get root_path
      assert_response :success
      assert_select "[data-module=crm]", count: 0
      assert_select "[data-capability=organizations]"
    end
  end

  test "home page hides both optional modules when neither is available" do
    with_stubbed_singleton_method(Foundation, :module_available?, lambda { |*|
      false
    }) do
      get root_path
      assert_response :success
      assert_select "[data-module=storefront]", count: 0
      assert_select "[data-module=crm]", count: 0
      assert_select "[data-capability=accounts]"
      assert_select "[data-capability=billing]"
      assert_select "[data-capability=native]"
    end
  end
end
