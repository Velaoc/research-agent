require "test_helper"
require "stringio"

# SPEC M10.3: nothing has to be seeded for the application to boot, and the
# storefront demo catalog must never appear in a real deployment.
class DemoSeedsTest < ActiveSupport::TestCase
  def env(name)
    ActiveSupport::StringInquirer.new(name)
  end

  test "demo seeds are limited to development and hosted previews" do
    assert Foundation::DemoSeeds.permitted?(rails_env: env("development"), preview: false)
    assert Foundation::DemoSeeds.permitted?(rails_env: env("production"), preview: true)
    assert_not Foundation::DemoSeeds.permitted?(rails_env: env("production"), preview: false)
    assert_not Foundation::DemoSeeds.permitted?(rails_env: env("test"), preview: false)
  end

  test "db/seeds.rb creates nothing in an environment that is not allowed to demo" do
    assert_not Foundation::DemoSeeds.permitted?

    assert_no_difference -> { Foundation::Storefront::Product.count } do
      capture_io { load Rails.root.join("db/seeds.rb").to_s }
    end
  end

  test "the demo catalog is idempotent where it is allowed" do
    with_env("VELA_HOLODEX_PREVIEW" => "1") do
      output = StringIO.new

      assert_difference -> { Foundation::Storefront::Product.count }, Foundation::DemoSeeds::PRODUCTS.length do
        Foundation::DemoSeeds.run!(io: output)
      end
      assert_no_difference -> { Foundation::Storefront::Product.count } do
        assert_equal 0, Foundation::DemoSeeds.run!(io: output)
      end

      assert_includes output.string, "Demo catalog ready"
    end
  end

  test "demo products are valid, available, and priced in whole cents" do
    with_env("VELA_HOLODEX_PREVIEW" => "1") do
      Foundation::DemoSeeds.run!(io: StringIO.new)

      products = Foundation::Storefront::Product.where(slug: Foundation::DemoSeeds::PRODUCTS.map { |row| row[:slug] })
      assert_equal Foundation::DemoSeeds::PRODUCTS.length, products.count
      products.each do |product|
        assert_predicate product, :valid?
        assert_predicate product, :available?
        assert_operator product.price_cents, :>, 0
        assert_equal "USD", product.currency
      end
    end
  end

  test "seeding creates no accounts and no administrators" do
    with_env("VELA_HOLODEX_PREVIEW" => "1") do
      assert_no_difference [ "User.count", "User.where(admin: true).count", "LegalAcceptance.count" ] do
        Foundation::DemoSeeds.run!(io: StringIO.new)
      end
    end
  end
end
