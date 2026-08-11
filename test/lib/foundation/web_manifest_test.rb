require "test_helper"

# SPEC M10.2: the web app manifest carries no identity of its own. Everything
# it publishes — name, description, and both colors — has to follow
# config/foundation.yml so bin/rename is enough to rebrand an installed app.
class WebManifestTest < ActiveSupport::TestCase
  IDENTITY = {
    application_name: "Acme Shop",
    default_page_description: "Licenses for the Acme toolchain",
    brand_seed_color: "#b3261e"
  }.with_indifferent_access

  def manifest(overrides = {})
    Foundation::WebManifest.new(IDENTITY.merge(overrides)).as_json
  end

  test "identity and colors come from configuration" do
    payload = manifest

    assert_equal "Acme Shop", payload.fetch("name")
    assert_equal "Licenses for the Acme toolchain", payload.fetch("description")
    assert_equal "#B3261E", payload.fetch("theme_color")
    assert_equal "#B3261E", payload.fetch("background_color")
    assert_equal "/", payload.fetch("start_url")
    assert_equal "/", payload.fetch("scope")
    assert_equal "standalone", payload.fetch("display")
  end

  test "both icon purposes point at the regenerable SVG mark" do
    icons = manifest.fetch("icons")

    assert_equal %w[any maskable], icons.map { |icon| icon.fetch("purpose") }
    icons.each do |icon|
      assert_equal "/icon.svg", icon.fetch("src")
      assert_equal "image/svg+xml", icon.fetch("type")
    end
  end

  test "the short name is truncated on a word boundary" do
    assert_equal "Acme Shop", manifest.fetch("short_name")
    assert_equal "Acme", manifest(application_name: "Acme Toolchain Licensing").fetch("short_name")
    assert_equal "Supercalifra", manifest(application_name: "Supercalifragilistic").fetch("short_name")
  end

  test "a blank product name falls back instead of publishing an empty label" do
    assert_equal "Application", manifest(application_name: "  ").fetch("name")
  end

  test "an unusable seed color is refused rather than silently themed" do
    assert_raises(Foundation::AppIcon::InvalidColor) { manifest(brand_seed_color: "rebeccapurple") }
  end
end
