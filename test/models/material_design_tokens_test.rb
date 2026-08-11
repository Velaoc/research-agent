require "test_helper"
require "digest"
require "json"

class MaterialDesignTokensTest < ActiveSupport::TestCase
  TOKEN_PATH = Rails.root.join("config/material_tokens.json")
  CSS_PATH = Rails.root.join("app/assets/stylesheets/material_tokens.css")
  SYSTEM_CSS_PATH = Rails.root.join("app/assets/stylesheets/material_system.css")

  test "generated token artifact is pinned and deterministic" do
    tokens = JSON.parse(TOKEN_PATH.read)
    metadata = tokens.fetch("metadata")

    assert_equal "@material/material-color-utilities", metadata.fetch("generator")
    assert_equal "0.4.0", metadata.fetch("version")
    assert_equal "SchemeTonalSpot", metadata.fetch("algorithm")
    assert_equal "Material dynamic color 2021", metadata.fetch("variant")
    assert_equal 0, metadata.fetch("contrastLevel")
    assert_equal Rails.configuration.x.foundation[:brand_seed_color].upcase, metadata.fetch("seed"),
      "brand_seed_color changed without regenerating the color tokens. " \
      "Run: node tools/material/dist/generate_tokens.mjs (requires Node locally; " \
      "the bundle is committed and self-contained), commit the regenerated " \
      "config/material_tokens.* and app/assets/stylesheets/material_tokens.css — " \
      "or revert brand_seed_color to the seed recorded in config/material_tokens.json. " \
      "Automated pipelines without Node should keep the committed palette."
    assert_equal Rails.root.join("config/material_tokens.sha256").read.strip,
      Digest::SHA256.file(TOKEN_PATH).hexdigest
  end

  test "offline generator bundle and rebuild verification are committed" do
    package = JSON.parse(Rails.root.join("tools/material/package.json").read)
    bundle = Rails.root.join("tools/material/dist/generate_tokens.mjs").read
    scripts = package.fetch("scripts")

    assert_includes scripts.fetch("test"), "verify:generator"
    assert_includes scripts.fetch("verify:generator"), "cmp dist/generate_tokens.mjs"
    assert_includes scripts.fetch("check:tokens"), "--check"
    assert_includes bundle, "SchemeTonalSpot"
    assert_includes bundle, "Material tokens need regeneration"
    assert_not_includes bundle, 'from "@material/material-color-utilities"'
  end

  test "every committed role is present in CSS for both schemes" do
    tokens = JSON.parse(TOKEN_PATH.read)
    css = CSS_PATH.read

    assert_equal tokens.fetch("schemes", "light").keys, tokens.fetch("schemes", "dark").keys
    tokens.fetch("schemes").each_value do |roles|
      roles.each { |role, color| assert_includes css, "--md-sys-color-#{role}: #{color};" }
    end
  end

  test "semantic foreground pairs meet WCAG AA contrast in both schemes" do
    pairs = %w[
      primary:on-primary primary-container:on-primary-container
      secondary:on-secondary secondary-container:on-secondary-container
      tertiary:on-tertiary tertiary-container:on-tertiary-container
      error:on-error error-container:on-error-container
      surface:on-surface surface-variant:on-surface-variant
      inverse-surface:inverse-on-surface
    ]

    JSON.parse(TOKEN_PATH.read).fetch("schemes").each do |scheme, roles|
      pairs.each do |pair|
        background, foreground = pair.split(":")
        ratio = contrast(roles.fetch(background), roles.fetch(foreground))
        assert_operator ratio, :>=, 4.5, "#{scheme} #{foreground} on #{background} contrast was #{ratio.round(2)}"
      end
    end
  end

  test "adaptive breakpoint and touch target contract is explicit" do
    css = SYSTEM_CSS_PATH.read

    [ 600, 840, 1200, 1600 ].each { |width| assert_includes css, "@media (min-width: #{width}px)" }
    assert_includes css, "@media (max-width: 599px)"
    assert_includes css, "min-height: 48px"
    assert_includes css, "prefers-reduced-motion: reduce"
    assert_includes css, "forced-colors: active"
    assert_not_includes css, "html { min-width:"
    assert_no_match(/(?:\{|;)\s*width:\s*(?:[4-9]\d{2,}|\d{4,})px/, css)
  end

  test "icon subset and mapping are pinned" do
    font = Rails.root.join("app/assets/fonts/material-symbols-rounded-subset.woff2")
    symbols = Rails.root.join("tools/material/symbols.txt").read.lines.filter_map { |line| line.split.first }

    assert_equal Foundation::MaterialHelper::MATERIAL_SYMBOLS.keys.sort, symbols.sort
    assert_operator font.size, :<, 50_000
    assert_equal "a74ff879c75afa6eec38340ff8185d0cbf1dbdbfe91d2d732f87950175840be5",
      Digest::SHA256.file(font).hexdigest
  end

  test "application views contain no fixed Tailwind palette utilities" do
    palette = /(?:text|bg|border|divide)-(?:gray|red|amber|green|blue|white)(?:-|\b)/
    offenders = Rails.root.glob("app/views/**/*.erb").filter_map do |path|
      path.relative_path_from(Rails.root).to_s if path.read.match?(palette)
    end

    assert_empty offenders, "replace fixed palette classes with semantic MD token utilities: #{offenders.join(", ")}"
  end

  test "Tailwind emits every semantic utility referenced by application views" do
    build = Rails.root.join("app/assets/builds/tailwind.css")
    assert_path_exists build, "the Rails test task must build Tailwind before running tests"

    referenced = Rails.root.glob("app/views/**/*.erb").flat_map do |path|
      path.read.scan(/(?:text|bg|border|divide|hover:(?:text|bg))-md-[a-z-]+/)
    end.uniq
    compiled = build.read

    referenced.each do |utility|
      selector = utility.gsub(":", "\\:")
      assert_includes compiled, ".#{selector}", "Tailwind did not emit #{utility}"
    end
  end

  private

  def contrast(first, second)
    high, low = [ luminance(first), luminance(second) ].sort.reverse
    (high + 0.05) / (low + 0.05)
  end

  def luminance(hex)
    hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }.then do |channels|
      channels.map! { |channel| channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4 }
      (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
    end
  end
end
