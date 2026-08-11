require "test_helper"

# SPEC M10.2: the shipped icon is a placeholder derived from the brand seed
# color, and it must stay derivable — no committed artwork that cannot be
# regenerated from configuration.
class AppIconTest < ActiveSupport::TestCase
  ICON = Rails.root.join(Foundation::AppIcon::PATH)

  test "the committed icon matches the configured brand seed" do
    assert_predicate ICON, :exist?
    assert_equal Foundation::AppIcon.svg(Rails.configuration.x.foundation[:brand_seed_color]), ICON.read,
      "public/icon.svg is stale; run bin/rails foundation:icon after changing brand_seed_color"
  end

  test "no unregenerable binary icon ships alongside it" do
    assert_not Rails.root.join("public/icon.png").exist?,
      "a binary icon cannot be regenerated from config/foundation.yml"
  end

  test "the artwork is square and stays inside the maskable safe zone" do
    svg = Foundation::AppIcon.svg("#6750A4")

    assert_includes svg, %(viewBox="0 0 512 512")
    assert_includes svg, %(<rect width="512" height="512" fill="#6750A4"/>)
    assert_operator Foundation::AppIcon::OUTER_RADIUS, :<=, Foundation::AppIcon::SAFE_RADIUS
    assert_operator Foundation::AppIcon::INNER_RADIUS, :<, Foundation::AppIcon::OUTER_RADIUS
  end

  test "generation is deterministic and depends only on the seed" do
    assert_equal Foundation::AppIcon.svg("#6750A4"), Foundation::AppIcon.svg("6750a4")
    assert_not_equal Foundation::AppIcon.svg("#6750A4"), Foundation::AppIcon.svg("#B3261E")
  end

  test "the mark contrasts with any seed color" do
    assert_equal "#FFFFFF", Foundation::AppIcon.foreground_for("#000000")
    assert_equal "#000000", Foundation::AppIcon.foreground_for("#FFFFFF")
    assert_equal "#000000", Foundation::AppIcon.foreground_for("#FFD400")
    assert_equal "#FFFFFF", Foundation::AppIcon.foreground_for("#6750A4")
  end

  test "an unusable seed color is refused rather than guessed" do
    [ "", "purple", "#12345", "#12345g", "#6750A4A4", "rgb(1,2,3)", nil ].each do |value|
      assert_raises(Foundation::AppIcon::InvalidColor, "expected #{value.inspect} to be refused") do
        Foundation::AppIcon.svg(value)
      end
    end
  end
end
