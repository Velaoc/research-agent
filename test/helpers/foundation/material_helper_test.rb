require "test_helper"

class Foundation::MaterialHelperTest < ActionView::TestCase
  include Foundation::MaterialHelper

  test "material symbols use the pinned subset codepoint and hide decorative icons" do
    output = material_symbol(:home, size: 28)

    assert_includes output, "\uE9B2"
    assert_includes output, "aria-hidden=\"true\""
    assert_not_includes output, ">home<"
    assert_not_includes output, "style="
  end

  test "material symbols support labels and reject glyphs outside the subset" do
    output = material_symbol(:warning, label: "Warning")

    assert_includes output, "role=\"img\""
    assert_includes output, "aria-label=\"Warning\""
    assert_raises(ArgumentError) { material_symbol("uncommitted_glyph") }
    assert_raises(ArgumentError) { material_symbol(:home, size: 21) }
  end

  test "buttons escape labels and expose disabled and loading states" do
    escaped = md_button("<script>alert(1)</script>", variant: :filled)
    disabled = md_button("Unavailable", href: "/unsafe", disabled: true)
    loading = md_button("Saving", loading: true)

    assert_includes escaped, "&lt;script&gt;"
    assert_not_includes escaped, "<script>"
    assert_includes disabled, "aria-disabled=\"true\""
    assert_not_includes disabled, "href=\"/unsafe\""
    assert_includes loading, "aria-busy=\"true\""
    assert_includes loading, "disabled=\"disabled\""
  end

  test "button and choice variants fail closed" do
    assert_raises(ArgumentError) { md_button("Bad", variant: :invented) }
    assert_raises(ArgumentError) { md_card(variant: :invented) { "Bad" } }

    form = Object.new
    assert_raises(ArgumentError) { md_choice(form, :setting, label: "Setting", type: :invented) }
    assert_equal %i[checkbox radio switch], Foundation::MaterialHelper::CHOICE_TYPES
  end

  test "cards escape attribute values while preserving captured content" do
    output = md_card(variant: :outlined, title: %("><script>x</script>)) { "Safe content" }

    assert_includes output, "Safe content"
    assert_includes output, "&quot;&gt;&lt;script&gt;"
    assert_not_includes output, "<script>"
  end

  test "dialog provides a native modal and an associated keyboard trigger" do
    output = md_dialog(id: "safe-dialog", title: "Confirm", trigger_label: "Open") { "Dialog content" }

    assert_includes output, "<dialog"
    assert_includes output, "foundation--dialog#open"
    assert_includes output, "aria-controls=\"safe-dialog\""
    assert_includes output, "Dialog content"
  end
end
