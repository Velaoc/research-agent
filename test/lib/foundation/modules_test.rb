# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# Generation-time module composition (docs/MODULES.md). Default checkouts keep
# every included module; omit is opt-in filesystem surgery reversible from git.
class FoundationModulesTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/foundation-modules").to_s

  setup do
    @root = Dir.mktmpdir("foundation-modules-test")
  end

  teardown { FileUtils.remove_entry(@root, true) }

  # These exercise the mechanism through the storefront, the only module
  # declared today. A generated application that omitted it still ships this
  # file, so they skip rather than fail there — otherwise the composition
  # system's own tests become the residue it exists to prevent. Any future
  # module gets the same treatment for free.
  def skip_without_storefront
    return if Foundation::Modules.registry(root: Rails.root).available?("storefront")

    skip "storefront module is not declared in this tree (omitted at generation)"
  end

  test "registry lists the storefront module as included by default" do
    skip_without_storefront
    registry = Foundation::Modules.registry(root: Rails.root)

    assert registry.available?("storefront")
    storefront = registry.fetch("storefront")
    assert_equal "included", storefront.default
    assert_includes storefront.paths, "app/models/foundation/storefront"
    assert_includes storefront.table_prefixes, "storefront_"
    assert Foundation.module_available?("storefront")
  end

  test "list command prints declared modules" do
    skip_without_storefront
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, SCRIPT, "list", "--root", Rails.root.to_s)

    assert_predicate status, :success?, stderr
    assert_match(/storefront\tdefault=included/, stdout)
  end

  test "omitting storefront leaves no structural residue and keeps core files" do
    skip_without_storefront
    mirror_template_into!(@root)

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, SCRIPT, "omit", "storefront", "--root", @root
    )

    assert_predicate status, :success?, "#{stderr}\n#{stdout}"
    assert_match(/Omitted module storefront/, stdout)

    refute File.exist?(File.join(@root, "app/models/foundation/storefront"))
    refute File.exist?(File.join(@root, "app/controllers/foundation/storefront"))
    refute File.exist?(File.join(@root, "db/migrate/20260811060001_create_storefront.rb"))
    refute File.exist?(File.join(@root, "config/foundation/modules/storefront.yml"))
    refute File.exist?(File.join(@root, "docs/STOREFRONT.md"))
    refute File.exist?(File.join(@root, "lib/foundation/demo_seeds.rb"))
    refute File.exist?(File.join(@root, "test/integration/storefront_flows_test.rb"))

    schema = File.read(File.join(@root, "db/schema.rb"), encoding: "UTF-8")
    refute_match(/create_table "storefront_/, schema)
    refute_match(/add_foreign_key "storefront_/, schema)

    foundation_yml = File.read(File.join(@root, "config/foundation.yml"), encoding: "UTF-8")
    refute_match(/storefront_enabled/, foundation_yml)
    refute_match(/storefront_fulfillment_mode/, foundation_yml)

    routes = File.read(File.join(@root, "config/routes.rb"), encoding: "UTF-8")
    refute_match(%r{foundation/storefront}, routes)
    refute_match(/storefront_stripe_webhook/, routes)
    assert_match(%r{root "foundation/home#show"}, routes)

    user = File.read(File.join(@root, "app/models/user.rb"), encoding: "UTF-8")
    refute_match(/storefront_orders/, user)
    refute_match(/Foundation::Storefront/, user)

    seeds = File.read(File.join(@root, "db/seeds.rb"), encoding: "UTF-8")
    refute_match(/DemoSeeds/, seeds)

    recurring = File.read(File.join(@root, "config/recurring.yml"), encoding: "UTF-8")
    refute_match(/Storefront::/, recurring)

    layout = File.read(File.join(@root, "app/views/layouts/application.html.erb"), encoding: "UTF-8")
    refute_match(/storefront_cart_path/, layout)
    assert_match(/Billing/, layout)

    css = File.read(File.join(@root, "app/assets/stylesheets/material_system.css"), encoding: "UTF-8")
    refute_match(/\.storefront-/, css)

    %w[
      app/models/user.rb
      config/routes.rb
      app/views/layouts/application.html.erb
      config/recurring.yml
      config/allgood.rb
    ].each do |relative|
      content = File.read(File.join(@root, relative), encoding: "UTF-8")
      refute_match(/foundation:module storefront/, content, relative)
    end

    assert File.exist?(File.join(@root, "app/models/user.rb"))
    assert File.exist?(File.join(@root, "config/routes.rb"))
    assert File.exist?(File.join(@root, "lib/foundation/modules/omit.rb"))
    assert File.exist?(File.join(@root, "docs/MODULES.md"))
  end

  test "default tree still has the storefront module on disk" do
    skip_without_storefront
    assert File.directory?(Rails.root.join("app/models/foundation/storefront"))
    assert File.file?(Rails.root.join("config/foundation/modules/storefront.yml"))
    assert_equal true, Rails.configuration.x.foundation[:storefront_enabled]
  end

  def skip_without_crm
    return if Foundation::Modules.registry(root: Rails.root).available?("crm")

    skip "crm module is not declared in this tree (omitted at generation)"
  end

  test "registry lists the crm module as included by default" do
    skip_without_crm
    registry = Foundation::Modules.registry(root: Rails.root)
    assert registry.available?("crm")
    crm = registry.fetch("crm")
    assert_equal "included", crm.default
    assert_includes crm.paths, "app/models/foundation/crm"
    assert_includes crm.table_prefixes, "crm_"
    assert Foundation.module_available?("crm")
  end

  test "omitting crm leaves no structural residue and keeps core files" do
    skip_without_crm
    mirror_template_into!(@root)

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, SCRIPT, "omit", "crm", "--root", @root
    )

    assert_predicate status, :success?, "#{stderr}\n#{stdout}"
    assert_match(/Omitted module crm/, stdout)

    refute File.exist?(File.join(@root, "app/models/foundation/crm"))
    refute File.exist?(File.join(@root, "app/controllers/foundation/crm"))
    refute File.exist?(File.join(@root, "db/migrate/20260811140000_create_crm.rb"))
    refute File.exist?(File.join(@root, "config/foundation/modules/crm.yml"))
    refute File.exist?(File.join(@root, "docs/CRM.md"))
    refute File.exist?(File.join(@root, "test/integration/crm_isolation_test.rb"))

    schema = File.read(File.join(@root, "db/schema.rb"), encoding: "UTF-8")
    refute_match(/create_table "crm_/, schema)
    refute_match(/add_foreign_key "crm_/, schema)

    routes = File.read(File.join(@root, "config/routes.rb"), encoding: "UTF-8")
    refute_match(%r{foundation/crm}, routes)
    refute_match(/crm_root_path/, routes)

    layout = File.read(File.join(@root, "app/views/layouts/application.html.erb"), encoding: "UTF-8")
    refute_match(/crm_root_path/, layout)
    refute_match(/label: "CRM"/, layout)

    helper = File.read(File.join(@root, "test/test_helper.rb"), encoding: "UTF-8")
    refute_match(/crm_test_helper/, helper)

    %w[
      config/routes.rb
      app/views/layouts/application.html.erb
      test/test_helper.rb
    ].each do |relative|
      content = File.read(File.join(@root, relative), encoding: "UTF-8")
      refute_match(/foundation:module crm/, content, relative)
    end

    assert File.exist?(File.join(@root, "app/models/user.rb"))
    assert File.exist?(File.join(@root, "config/routes.rb"))
    assert File.exist?(File.join(@root, "lib/foundation/modules/omit.rb"))
  end

  private

  def mirror_template_into!(destination)
    %w[app bin config db docs lib script test README.md SPEC.md PROVENANCE.md].each do |entry|
      source = Rails.root.join(entry)
      next unless File.exist?(source)

      FileUtils.cp_r(source, File.join(destination, entry))
    end

    %w[
      test/fixtures/files
      app/assets/builds
      app/assets/images
      app/assets/fonts
      tmp log storage
    ].each do |relative|
      FileUtils.rm_rf(File.join(destination, relative))
    end
  end
end
