require "test_helper"

# SPEC M10.2: the manifest is public, describes the configured product, and
# is linked from the pages an installable application is reached through.
class PwaManifestTest < ActionDispatch::IntegrationTest
  test "the manifest is public and rendered from config/foundation.yml" do
    identity = Rails.configuration.x.foundation

    get pwa_manifest_path

    assert_response :success
    assert_equal "application/manifest+json", response.media_type

    payload = JSON.parse(response.body)
    assert_equal identity[:application_name], payload.fetch("name")
    assert_equal identity[:default_page_description], payload.fetch("description")
    assert_equal Foundation::AppIcon.normalize_color(identity[:brand_seed_color]), payload.fetch("theme_color")
    assert_equal payload.fetch("theme_color"), payload.fetch("background_color")
    assert_equal [ "any", "maskable" ], payload.fetch("icons").map { |icon| icon.fetch("purpose") }
  end

  test "public pages link the manifest and the icon" do
    get root_path

    assert_response :success
    assert_select "link[rel=manifest][href=?]", pwa_manifest_path
    assert_select "link[rel=icon][href='/icon.svg'][type='image/svg+xml']"
  end

  test "no service worker is registered" do
    get root_path

    assert_response :success
    assert_no_match(/serviceWorker/, response.body)

    get "/service-worker"
    assert_response :not_found
  end
end
