require "test_helper"

class StorefrontCsvImporterTest < ActiveSupport::TestCase
  test "valid rows commit while invalid rows produce actionable errors" do
    csv = <<~CSV
      name,price,slug,currency,inventory_quantity,active
      Valid download,19.95,valid-download,usd,3,true
      Broken download,12.345,broken-download,USD,2,true
    CSV
    result = Foundation::Storefront::CsvImporter.call(csv)
    assert_equal 1, result.created
    assert_equal 1, result.errors
    assert_equal 1_995, Foundation::Storefront::Product.find_by!(slug: "valid-download").price_cents
    assert_match(/plain decimal notation/, result.rows.last.errors.to_sentence)
  end

  test "upsert by slug updates only named safe fields" do
    product = create_storefront_product(slug: "same-slug", sku: "UNCHANGED")
    result = Foundation::Storefront::CsvImporter.call("name,price_cents,slug\nUpdated,2500,same-slug\n")
    assert_equal 1, result.updated
    product.reload
    assert_equal "Updated", product.name
    assert_equal 2_500, product.price_cents
  end

  test "formulas unknown headers malformed quotes and hostile types fail closed" do
    formula = Foundation::Storefront::CsvImporter.call("name,price\n=cmd,10.00\n")
    assert_equal :error, formula.rows.sole.status
    assert_match(/formulas/, formula.rows.sole.errors.to_sentence)

    assert_raises(ArgumentError) { Foundation::Storefront::CsvImporter.call("name,price,path\nThing,1.00,/etc/passwd\n") }
    assert_raises(ArgumentError) { Foundation::Storefront::CsvImporter.call("name,price\n\"unterminated,1.00\n") }
    numeric = Foundation::Storefront::CsvImporter.call("name,price\nThing,NaN\n")
    assert_equal :error, numeric.rows.sole.status
  end

  test "size row and encoding limits are enforced" do
    assert_raises(ArgumentError) { Foundation::Storefront::CsvImporter.call("x" * (1.megabyte + 1)) }
    rows = ([ "name,price" ] + 501.times.map { |index| "Item #{index},1.00" }).join("\n")
    assert_raises(ArgumentError) { Foundation::Storefront::CsvImporter.call(rows) }
    invalid = "name,price\nBad,1.00\xFF".b
    assert_raises(ArgumentError) { Foundation::Storefront::CsvImporter.call(invalid) }
  end

  test "exponents and oversized numeric fields become row errors without aborting valid rows" do
    csv = <<~CSV
      name,price,price_cents,position,inventory_quantity
      Valid bounded,10.00,,1,2
      Exponent,1e1000000,,1,2
      Huge cents,,999999999999999999999,1,2
      Huge position,1.00,,999999999999999999999,2
      Huge inventory,1.00,,1,999999999999999999999
    CSV
    result = Foundation::Storefront::CsvImporter.call(csv)
    assert_equal 1, result.created
    assert_equal 4, result.errors
    assert Foundation::Storefront::Product.exists?(name: "Valid bounded")
  end
end
