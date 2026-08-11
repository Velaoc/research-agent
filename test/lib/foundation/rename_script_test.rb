require "test_helper"
require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

# bin/rename is the only command an automated generator runs against a freshly
# created application, so its argument handling is a security boundary: it has
# to stamp the identity, do it identically every time, and refuse anything
# that does not look like a product identity (SPEC M10.1).
class RenameScriptTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/rename").to_s
  TEMPLATE_FILES = %w[config/foundation.yml config/application.rb README.md].freeze

  IDENTITY_ARGS = [
    "--name", "Acme Shop",
    "--description", "Licenses for the Acme toolchain",
    "--domain", "acme.example",
    "--support-email", "support@acme.example",
    "--legal-email", "legal@acme.example"
  ].freeze

  # Each of these must be refused outright: command substitution, argument
  # injection, YAML/document injection, header injection, control characters,
  # non-ASCII homoglyph territory, and absurd lengths. (A NUL byte cannot be
  # passed through exec at all, so the operating system rejects that one for
  # us; the printable-ASCII gate covers every other control character.)
  HOSTILE_NAMES = [
    "Acme; rm -rf /",
    "Acme && curl http://example.invalid",
    "$(id)",
    "`id`",
    "Acme | tee /etc/passwd",
    "Acme\nadmin: true",
    "Acme\r\napplication_name: Evil",
    "Acme  Shop",
    "Acme \"quoted\"",
    "Acme\\",
    "#comment",
    "Ünicode",
    " Acme",
    "Acme ",
    "A" * 61,
    ""
  ].freeze

  HOSTILE_DOMAINS = [
    "https://evil.example",
    "evil.example/path",
    "evil.example:443",
    "evil.example.",
    "-evil.example",
    "evil",
    "evil.example\nx",
    "a" * 300
  ].freeze

  HOSTILE_EMAILS = [
    "support@acme.example\nBcc: attacker@evil.example",
    "support@acme",
    "support acme@example.com",
    "<script>@acme.example",
    "@acme.example"
  ].freeze

  HOSTILE_MODULES = %w[
    Foundation Rails Application String Hash Object Data Comparable
    lowercase With-Dash 9Lives
  ].freeze

  setup do
    @root = Dir.mktmpdir("rename-script-test")
    TEMPLATE_FILES.each do |relative|
      FileUtils.mkdir_p(File.join(@root, File.dirname(relative)))
      FileUtils.cp(Rails.root.join(relative), File.join(@root, relative))
    end
  end

  teardown { FileUtils.remove_entry(@root, true) }

  test "stamps the identity into configuration, the README, and the manifest" do
    stdout, stderr, status = rename(*IDENTITY_ARGS)

    assert_predicate status, :success?, stderr
    identity = stamped_identity
    assert_equal "Acme Shop", identity.fetch("application_name")
    assert_equal "Licenses for the Acme toolchain", identity.fetch("default_page_description")
    assert_equal "acme.example", identity.fetch("domain")
    assert_equal "support@acme.example", identity.fetch("support_email")
    assert_equal "legal@acme.example", identity.fetch("legal_email")

    readme = File.read(File.join(@root, "README.md"))
    assert_includes readme, "# Acme Shop"
    assert_includes readme, "- Site: https://acme.example"
    assert_includes readme, "- Support: support@acme.example"

    # The web app manifest carries no identity of its own; it is rendered from
    # the file this script just stamped.
    manifest = Foundation::WebManifest.new(identity.with_indifferent_access).as_json
    assert_equal "Acme Shop", manifest.fetch("name")
    assert_equal "Licenses for the Acme toolchain", manifest.fetch("description")

    assert_includes stdout, "Stamped product identity"
    assert_includes stdout, "Legal: review every TODO-OPERATOR"
    assert_includes stdout, "Mail: set SMTP_ADDRESS"
  end

  test "comments and unrelated settings survive the rewrite" do
    original = File.read(File.join(@root, "config/foundation.yml"))
    original_identity = YAML.safe_load(original).fetch("shared")
    _stdout, stderr, status = rename(*IDENTITY_ARGS)

    assert_predicate status, :success?, stderr
    rewritten = File.read(File.join(@root, "config/foundation.yml"))
    assert_equal original.lines.length, rewritten.lines.length
    assert_includes rewritten, "# Display name used in page titles, meta tags, and mail."
    # Settings the script does not stamp must come through byte-identical —
    # compared against their pre-run values, never against template defaults,
    # because this test also runs inside generated applications that have
    # legitimately customized them (a real app's changed brand seed once
    # failed here purely for not being the template's default).
    # foundation:module storefront
    assert_equal original_identity.fetch("storefront_enabled"), stamped_identity.fetch("storefront_enabled")
    # /foundation:module storefront
    assert_equal original_identity.fetch("brand_seed_color"), stamped_identity.fetch("brand_seed_color")
  end

  test "running twice with the same arguments changes nothing the second time" do
    _stdout, _stderr, status = rename(*IDENTITY_ARGS)
    assert_predicate status, :success?

    after_first = digests
    stdout, stderr, status = rename(*IDENTITY_ARGS)

    assert_predicate status, :success?, stderr
    assert_equal after_first, digests
    assert_includes stdout, "already carry this identity"
  end

  test "the application module is left alone unless it is asked for" do
    _stdout, _stderr, status = rename(*IDENTITY_ARGS)

    assert_predicate status, :success?
    assert_equal Digest::SHA256.file(Rails.root.join("config/application.rb")).hexdigest,
      digests.fetch("config/application.rb"),
      "config/application.rb must not change without --module"

    _stdout, stderr, status = rename(*IDENTITY_ARGS, "--module", "AcmeShop")
    assert_predicate status, :success?, stderr
    assert_match(/^module AcmeShop$/, File.read(File.join(@root, "config/application.rb")))

    before = digests
    _stdout, _stderr, status = rename(*IDENTITY_ARGS, "--module", "AcmeShop")
    assert_predicate status, :success?
    assert_equal before, digests, "a repeated module rename must be a no-op"
  end

  test "check mode reports the plan and writes nothing" do
    before = digests
    stdout, stderr, status = rename(*IDENTITY_ARGS, "--check")

    assert_predicate status, :success?, stderr
    assert_includes stdout, "Planned changes (nothing written)"
    assert_includes stdout, "would update config/foundation.yml"
    assert_equal before, digests
  end

  test "hostile product names are rejected and nothing is written" do
    HOSTILE_NAMES.each { |value| assert_rejected([ "--name", value ], value) }
  end

  test "hostile domains and mailboxes are rejected and nothing is written" do
    HOSTILE_DOMAINS.each { |value| assert_rejected([ "--name", "Acme", "--domain", value ], value) }
    HOSTILE_EMAILS.each { |value| assert_rejected([ "--name", "Acme", "--support-email", value ], value) }
    HOSTILE_EMAILS.each { |value| assert_rejected([ "--name", "Acme", "--legal-email", value ], value) }
  end

  test "module names that would collide with an existing constant are rejected" do
    HOSTILE_MODULES.each { |value| assert_rejected([ "--name", "Acme", "--module", value ], value) }
  end

  test "unknown options, missing names, and bad roots are refused" do
    assert_rejected([ "--name", "Acme", "--publish" ], "--publish")
    assert_rejected([ "--description", "No name given" ], "missing --name")
    assert_rejected([ "--name", "Acme", "--root", File.join(@root, "nowhere") ], "missing root")
  end

  private

  def rename(*args)
    Open3.capture3(RbConfig.ruby, SCRIPT, "--root", @root, *args)
  end

  def digests
    TEMPLATE_FILES.index_with { |relative| Digest::SHA256.file(File.join(@root, relative)).hexdigest }
  end

  def stamped_identity
    YAML.safe_load_file(File.join(@root, "config/foundation.yml"), aliases: true).fetch("shared")
  end

  def assert_rejected(args, label)
    before = digests
    stdout, stderr, status = rename(*args)

    assert_equal 1, status.exitstatus, "expected #{label.inspect} to be rejected (stdout: #{stdout})"
    assert_match(/\Abin\/rename: /, stderr, "expected an explanation for #{label.inspect}")
    assert_equal before, digests, "a rejected run must not write anything (#{label.inspect})"
  end
end
