# frozen_string_literal: true

require "test_helper"

# SPEC M14: native shell server contract. The single most important property
# is that ordinary browsers never receive native-only behaviour.
class NativeShellTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery"
  NATIVE_IOS_UA = "Application/1.0 (iPhone; iOS 18.0; build 1) Hotwire Native iOS"
  NATIVE_ANDROID_UA = "Hotwire Native Android; Mozilla/5.0 (Linux; Android 14)"
  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"

  # --- Browser isolation (most important) ---------------------------------

  test "ordinary browsers never receive native-only endpoints" do
    [
      native_path_configuration_path(platform: "ios", version: 1),
      native_path_configuration_path(platform: "android", version: 1),
      native_entry_path,
      native_auth_path,
      native_session_path
    ].each do |path|
      get path, headers: { "User-Agent" => BROWSER_UA }
      assert_response :not_found, "#{path} must 404 for browsers"
    end
  end

  test "requests without a native UA marker never receive native-only endpoints" do
    get native_session_path
    assert_response :not_found

    get native_auth_path, headers: { "User-Agent" => "curl/8.0" }
    assert_response :not_found
  end

  # --- Path configuration -------------------------------------------------

  test "native iOS shell receives versioned path configuration" do
    get native_path_configuration_path(platform: "ios", version: 1),
      headers: { "User-Agent" => NATIVE_IOS_UA }

    assert_response :success
    assert_equal "application/json", response.media_type

    payload = JSON.parse(response.body)
    assert_kind_of Hash, payload.fetch("settings")
    assert_kind_of Array, payload.fetch("rules")
    assert payload.fetch("rules").any? { |rule| rule.dig("properties", "context") == "default" }
    assert payload.fetch("rules").any? { |rule|
      Array(rule["patterns"]).any? { |pattern| pattern.include?("sign_in") }
    }
  end

  test "native Android shell receives versioned path configuration" do
    get native_path_configuration_path(platform: "android", version: 1),
      headers: { "User-Agent" => NATIVE_ANDROID_UA }

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload.fetch("rules").any? { |rule| rule.dig("properties", "uri").present? }
  end

  test "unknown path configuration version is not found" do
    get native_path_configuration_path(platform: "ios", version: 99),
      headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_response :not_found
  end

  test "unknown path configuration platform is not found" do
    get "/native/configurations/windows/v1",
      headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_response :not_found
  end

  # --- Entry / auth handoff -----------------------------------------------

  test "native guest entry redirects to the native auth landing" do
    get native_entry_path, headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_redirected_to native_auth_path
  end

  test "native auth landing is MD3 and has no emoji" do
    get native_auth_path, headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_response :success
    assert_select "h1", text: "Sign in"
    assert_select "form[action=?]", user_session_path
    assert_no_match(/\p{Emoji_Presentation}/, response.body)
  end

  test "native signed-in entry hands off via turbo recede location" do
    sign_in_native users(:confirmed)
    get native_entry_path, headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_redirected_to turbo_recede_historical_location_path
  end

  test "native password sign-in sets a remember-me cookie" do
    post user_session_path,
      params: { user: { email: users(:confirmed).email, password: PASSWORD } },
      headers: { "User-Agent" => NATIVE_IOS_UA }

    assert_response :redirect
    assert_redirected_to native_entry_path
    assert cookies["remember_user_token"].present?, "native sign-in must set remember_user_token"
  end

  test "browser password sign-in does not force remember-me" do
    post user_session_path,
      params: { user: { email: users(:confirmed).email, password: PASSWORD } },
      headers: { "User-Agent" => BROWSER_UA }

    assert_response :redirect
    assert_not_equal native_entry_path, path_only(response.redirect_url)
    assert cookies["remember_user_token"].blank?
  end

  # --- Session poll -------------------------------------------------------

  test "native session poll reports signed-out state" do
    get native_session_path, headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal false, payload.fetch("signed_in")
    assert_nil payload.fetch("user")
  end

  test "native session poll reports signed-in state" do
    sign_in_native users(:confirmed)
    get native_session_path, headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("signed_in")
    assert_equal users(:confirmed).id, payload.fetch("user").fetch("id")
    assert_equal users(:confirmed).email, payload.fetch("user").fetch("email")
  end

  # --- Association files --------------------------------------------------

  test "unconfigured association files return 404 without crashing" do
    get apple_app_site_association_path
    assert_response :not_found

    get android_assetlinks_path
    assert_response :not_found

    get "/apple-app-site-association"
    assert_response :not_found
  end

  test "configured apple-app-site-association is public JSON from configuration" do
    with_native_config(
      ios_app_id: "TEAMID.com.example.app",
      ios_paths: [ "/app/*", "NOT /admin/*" ]
    ) do
      get apple_app_site_association_path
      assert_response :success
      assert_equal "application/json", response.media_type

      payload = JSON.parse(response.body)
      detail = payload.fetch("applinks").fetch("details").first
      assert_equal "TEAMID.com.example.app", detail.fetch("appID")
      assert_equal [ "/app/*", "NOT /admin/*" ], detail.fetch("paths")
      assert_equal [], payload.fetch("applinks").fetch("apps")
    end
  end

  test "configured assetlinks.json is public JSON from configuration" do
    fingerprints = [ "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99" ]
    with_native_config(
      android_package_name: "com.example.app",
      android_sha256_cert_fingerprints: fingerprints
    ) do
      get android_assetlinks_path
      assert_response :success
      assert_equal "application/json", response.media_type

      payload = JSON.parse(response.body)
      assert_equal 1, payload.size
      target = payload.first.fetch("target")
      assert_equal "android_app", target.fetch("namespace")
      assert_equal "com.example.app", target.fetch("package_name")
      assert_equal fingerprints, target.fetch("sha256_cert_fingerprints")
      assert_includes payload.first.fetch("relation"), "delegate_permission/common.handle_all_urls"
    end
  end

  test "association files do not require authentication" do
    with_native_config(ios_app_id: "TEAMID.com.example.app") do
      get apple_app_site_association_path
      assert_response :success
    end
  end

  test "PWA manifest continues to work alongside native endpoints" do
    get pwa_manifest_path
    assert_response :success
    assert_equal "application/manifest+json", response.media_type
  end

  # --- Step-up reauthentication is not bypassed ---------------------------

  test "native shell still requires step-up before gated billing portal" do
    sign_in_native users(:confirmed)
    organization = Organizations::Organization.create!(name: "Native Org")
    Organizations::Membership.create!(user: users(:confirmed), organization: organization, role: "owner")
    post organizations.switch_organization_path(organization),
      headers: { "User-Agent" => NATIVE_IOS_UA }

    post billing_portal_path, headers: { "User-Agent" => NATIVE_IOS_UA }
    assert_redirected_to new_reauthentication_path
  end

  private

  def sign_in_native(user, password: PASSWORD)
    post user_session_path,
      params: { user: { email: user.email, password: password } },
      headers: { "User-Agent" => NATIVE_IOS_UA }
    follow_redirect! while response.redirect? && path_only(response.redirect_url) == native_entry_path
  end

  def path_only(url)
    return url if url.blank?
    uri = URI.parse(url)
    uri.path.presence || "/"
  rescue URI::InvalidURIError
    url.to_s
  end

  def with_native_config(overrides)
    foundation = Rails.configuration.x.foundation
    previous = foundation[:native]
    foundation[:native] = (previous || {}).deep_dup.merge(overrides.stringify_keys).with_indifferent_access
    yield
  ensure
    foundation[:native] = previous
  end
end
