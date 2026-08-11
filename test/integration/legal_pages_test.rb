require "test_helper"

# SPEC M2.4: the legal documents must actually exist, be substantive, and
# carry visible version identifiers — enforced here so a fork cannot quietly
# ship an empty terms page.
class LegalPagesTest < ActionDispatch::IntegrationTest
  SUBSTANCE_THRESHOLD = 60 # non-blank lines per document

  DOCUMENT_SOURCES = {
    "terms" => Rails.root.join("app/views/foundation/legal/terms.html.erb"),
    "privacy" => Rails.root.join("app/views/foundation/legal/privacy.html.erb")
  }.freeze

  test "both documents exist and exceed the substance threshold" do
    DOCUMENT_SOURCES.each do |name, path|
      assert path.exist?, "expected the #{name} document at #{path}"

      non_blank_lines = path.read.lines.count { |line| line.strip.present? }

      assert_operator non_blank_lines, :>=, SUBSTANCE_THRESHOLD,
        "#{name} has #{non_blank_lines} non-blank lines; the template promises at least #{SUBSTANCE_THRESHOLD}"
    end
  end

  test "terms page renders with a visible version identifier and operator markers" do
    get legal_terms_path

    assert_response :success
    assert_includes response.body, Foundation::Legal.terms_label
    assert_match(/v\d+ — \d{4}-\d{2}-\d{2}/, response.body, "version identifier must be visible")
    assert_includes response.body, "TODO-OPERATOR"
  end

  test "privacy page renders with a visible version identifier and operator markers" do
    get legal_privacy_path

    assert_response :success
    assert_includes response.body, Foundation::Legal.privacy_label
    assert_match(/v\d+ — \d{4}-\d{2}-\d{2}/, response.body, "version identifier must be visible")
    assert_includes response.body, "TODO-OPERATOR"
  end

  test "legal pages are reachable without an account" do
    get legal_terms_path
    assert_response :success

    get legal_privacy_path
    assert_response :success
  end

  # The Terms and Privacy links are a product contract, not decoration: every
  # place a person agrees to them, and the public footer, must offer them
  # (SPEC M2.4 and M8.3). Without these assertions an edit could drop a link
  # and every other gate would stay green.
  test "the signup page links both legal documents" do
    get new_user_registration_path

    assert_response :success
    assert_legal_links("the signup page")
  end

  # foundation:module storefront
  test "the guest checkout page links both legal documents" do
    assert Foundation.storefront_enabled?, "the template ships with the storefront enabled"
    product = create_storefront_product
    post items_storefront_cart_path(product), params: { quantity: 1 }

    get storefront_checkout_path

    assert_response :success
    assert_legal_links("the checkout page")
  end
  # /foundation:module storefront

  test "the OAuth assent interstitial links both legal documents" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "uid-legal-links", info: { email: "newcomer@example.com" }
    )
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect! # provider callback
    follow_redirect! # assent interstitial

    assert_response :success
    assert_legal_links("the OAuth assent page")
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.except!(:google_oauth2)
  end

  test "the public footer links both legal documents" do
    get root_path

    assert_response :success
    assert_select "footer.md-footer" do
      assert_select "a[href=?]", legal_terms_path, { minimum: 1 }, "the footer must link the Terms of Service"
      assert_select "a[href=?]", legal_privacy_path, { minimum: 1 }, "the footer must link the Privacy Policy"
    end
  end

  private

  def assert_legal_links(where)
    assert_select "a[href=?]", legal_terms_path, { minimum: 1 }, "#{where} must link the Terms of Service"
    assert_select "a[href=?]", legal_privacy_path, { minimum: 1 }, "#{where} must link the Privacy Policy"
  end
end
