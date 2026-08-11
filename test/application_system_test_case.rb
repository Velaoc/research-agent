require "test_helper"

# Base class for browser-driven tests. Everything under test/system runs
# against a real headless Chrome, so these tests can confirm what
# request-level tests cannot: that the compiled stylesheet is actually
# served and applied, that links and forms are reachable by a person
# clicking them, and that a guest can walk the storefront end to end.
#
# The stock Rails split applies: `bin/rails test` skips test/system,
# `bin/rails test:system` runs only test/system.
#
# Selenium Manager resolves the driver from the installed browser, so no
# driver binary is committed or downloaded ahead of time.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # 1400x900 is past the 1200px breakpoint where the adaptive navigation
  # becomes an expanded rail, so signed-in pages render their widest layout.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ] do |options|
    # Containers default /dev/shm to 64 MB, which crashes the renderer part
    # way through a page. Writing shared memory to /tmp instead costs a
    # little speed and is harmless everywhere else.
    options.add_argument("--disable-dev-shm-usage")

    # Chrome refuses to start its own sandbox as root, which is how a
    # container-based dev loop usually runs the suite. Hosted CI runners are
    # unprivileged, so they keep the sandbox.
    options.add_argument("--no-sandbox") if Process.uid.zero?
  end
end
