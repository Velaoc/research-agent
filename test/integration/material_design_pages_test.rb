require "test_helper"

class MaterialDesignPagesTest < ActionDispatch::IntegrationTest
  test "public landing exposes the storefront catalog and public shell" do
    get root_path

    assert_response :success
    assert_select "a.md-skip-link[href='#main-content']", text: "Skip to main content"
    # foundation:module storefront
    assert_select "h1", text: "Shop"
    assert_select "a[href='#{storefront_cart_path}']", minimum: 1
    assert_select ".md-pricing-grid", count: 0
    # /foundation:module storefront
    assert_select "footer a", text: "Terms of Service"
  end

  test "auth and pricing pages use local Material assets without a font CDN" do
    get new_user_session_path
    assert_response :success
    assert_select "form input[type=email]"
    assert_select "form input[type=password]"

    get pricing_path
    assert_response :success
    assert_select ".md-tabs"
    assert_select ".md-price-card", count: PricingPlans.plans.size
    assert_select "button[data-foundation--theme-target=button][aria-haspopup]", count: 0
    assert_not_includes response.body, "fonts.googleapis.com"
    assert_not_includes response.body, "fonts.gstatic.com"
  end

  test "authenticated shell renders one adaptive navigation and reachable sign out" do
    post user_session_path, params: { user: { email: users(:confirmed).email, password: "correct horse battery" } }
    follow_redirect!

    assert_response :success
    assert_select "nav.md-navigation", count: 1
    # foundation:module storefront
    assert_select "nav.md-navigation a", text: /Shop/
    # /foundation:module storefront
    assert_select "nav.md-navigation form button.md-navigation__signout", text: "Sign out", count: 1
    assert_select "main#main-content.md-main"
  end

  test "static error pages use the branded responsive surface" do
    %w[404 422 500].each do |status|
      page = Rails.root.join("public/#{status}.html").read

      assert_includes page, "class=\"mark\""
      assert_includes page, "Error #{status}"
      assert_includes page, "prefers-color-scheme:dark"
      assert_not_includes page, "<svg"
      assert_not_includes page, "application owner"
    end
  end

  test "admin shell uses local token assets and text navigation" do
    post user_session_path, params: { user: { email: users(:admin).email, password: "correct horse battery" } }
    get madmin_root_path

    assert_response :success
    assert_select ".md-admin-shell"
    assert_select "aside.md-admin-nav"
    assert_select "main#admin-content"
    assert_not_includes response.body, "unpkg.com"
    assert_not_includes response.body, "<svg"
  end
end
