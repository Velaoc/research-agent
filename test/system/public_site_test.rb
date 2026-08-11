require "application_system_test_case"

# The public shell is what an unauthenticated visitor sees on every page:
# the top app bar, the main region, and the footer. A request test can only
# prove the markup exists; these prove a browser renders it, styles it, and
# lets someone click through it.
class PublicSiteTest < ApplicationSystemTestCase
  # Material Design 3 puts the floor for a pointer target at 48x48 density
  # independent pixels.
  MINIMUM_TOUCH_TARGET = 48

  test "the public landing page renders with its primary navigation" do
    visit root_path

    assert_selector "main#main-content"
    # foundation:module storefront
    assert_selector "h1", text: "Shop"
    # /foundation:module storefront
    assert_selector "a.md-skip-link[href='#main-content']", visible: :all

    within "header.md-top-app-bar" do
      assert_link Rails.configuration.x.foundation[:application_name], href: root_path
      # foundation:module storefront
      assert_link "Shop", href: storefront_products_path
      assert_link "Cart", href: storefront_cart_path
      # /foundation:module storefront
      assert_link "Sign in", href: new_user_session_path
    end

    # The adaptive navigation belongs to the signed-in shell only; a guest
    # page that grew one would be leaking the authenticated layout.
    assert_no_selector "nav.md-navigation"
  end

  test "the public footer reaches both legal documents" do
    visit root_path
    within("footer.md-footer") { click_on "Terms of Service" }

    assert_current_path legal_terms_path
    assert_selector "h1", text: "Terms of Service"

    visit root_path
    within("footer.md-footer") { click_on "Privacy Policy" }

    assert_current_path legal_privacy_path
    assert_selector "h1", text: "Privacy Policy"
  end

  # This is the assertion no request test can make: it measures elements
  # after the browser has fetched and applied the compiled stylesheet. If
  # the stylesheet stopped being served, or a control lost its Material
  # class, every one of these collapses to line height and the test fails.
  test "public controls meet the minimum pointer target size" do
    visit root_path

    assert_selector "header.md-top-app-bar a", minimum: 4
    assert_selector "footer.md-footer a", minimum: 4

    undersized = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll(
        "header.md-top-app-bar a, header.md-top-app-bar button, footer.md-footer a"
      )).map(function (element) {
        return [ element.textContent.trim(), Math.round(element.getBoundingClientRect().height) ];
      }).filter(function (measurement) {
        return measurement[1] < #{MINIMUM_TOUCH_TARGET};
      });
    JAVASCRIPT

    assert_empty undersized,
      "every public control must be at least #{MINIMUM_TOUCH_TARGET}px tall; measured #{undersized.inspect}"
  end
end
