require "application_system_test_case"

# The storefront ships enabled, and its central promise is that a visitor
# with no account can go from the catalog to the checkout page. Each hop
# here depends on the previous page's real markup, a session cookie the
# browser carries itself, and a Turbo form submission, so a broken link,
# an unclickable button, or a lost cart session fails the test.
#
# The final submit is deliberately not clicked: it hands off to Stripe, and
# the suite makes no network calls.
class StorefrontGuestCheckoutTest < ApplicationSystemTestCase
  test "a guest walks from the catalog to checkout without an account" do
    product = create_storefront_product(
      name: "Field Notes Bundle",
      slug: "field-notes-bundle",
      sku: "FIELD-NOTES-BUNDLE",
      description: "A downloadable bundle of field notes.",
      price_cents: 2_500,
      inventory_quantity: 5
    )

    visit root_path
    assert_selector ".storefront-product-card", count: 1
    click_on product.name

    assert_current_path storefront_product_path(product.slug)
    assert_selector "h1", text: product.name
    assert_text "USD 25.00"
    click_on "Add to cart"

    assert_current_path storefront_cart_path
    assert_selector ".storefront-cart-item", text: product.name
    assert_selector ".storefront-total", text: "USD 25.00"
    click_on "Continue to checkout"

    assert_current_path storefront_checkout_path
    assert_selector "h1", text: "Contact and consent"

    within ".md-auth-card" do
      assert_field "checkout[email]", type: "email"
      # The input itself is deliberately reduced to 1px and transparent by the
      # design system, so presence alone would still pass with nothing on
      # screen. Assert the control the shopper actually sees and clicks, and
      # that ticking it registers on the hidden input underneath.
      assert_selector "input[type=checkbox][name='checkout[legal_assent]']", visible: :all
      assert_selector ".md-choice--checkbox .md-choice__control"
      consent = find("input[type=checkbox][name='checkout[legal_assent]']", visible: :all)
      assert_not consent.checked?, "consent must start unticked"
      check "checkout[legal_assent]", allow_label_click: true
      assert consent.checked?, "the consent box must be tickable from its label"
      assert_link "Terms of Service", href: legal_terms_path
      assert_link "Privacy Policy", href: legal_privacy_path
      assert_selector "input[type=submit]"
    end

    # Still a guest at the end of the flow: no account was created and none
    # was demanded along the way.
    within("header.md-top-app-bar") { assert_link "Sign in", href: new_user_session_path }
    assert_no_selector "nav.md-navigation"
  end
end
