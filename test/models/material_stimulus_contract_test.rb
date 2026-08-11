require "test_helper"

class MaterialStimulusContractTest < ActiveSupport::TestCase
  CONTROLLERS = Rails.root.join("app/javascript/controllers/foundation")

  test "theme controller uses a private local preference with system fallback" do
    source = CONTROLLERS.join("theme_controller.js").read

    assert_includes source, 'const THEMES = ["system", "light", "dark"]'
    assert_includes source, 'const STORAGE_KEY = "foundation.color-theme"'
    assert_includes source, "localStorage.setItem"
    assert_includes source, "prefers-color-scheme: dark"
    assert_includes source, 'addEventListener("change"'
    assert_not_includes source, "fetch("
  end

  test "dialog menu and tabs expose keyboard and dismissal contracts" do
    dialog = CONTROLLERS.join("dialog_controller.js").read
    menu = CONTROLLERS.join("menu_controller.js").read
    tabs = CONTROLLERS.join("tabs_controller.js").read

    assert_includes dialog, "showModal()"
    assert_includes dialog, "this.dialogTarget.close()"
    assert_includes menu, 'event.key === "Escape"'
    assert_includes menu, '"ArrowDown"'
    assert_includes menu, "pointerdown"
    assert_includes tabs, '"ArrowLeft"'
    assert_includes tabs, '"ArrowRight"'
  end
end
