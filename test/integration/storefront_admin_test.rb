require "test_helper"

class StorefrontAdminTest < ActionDispatch::IntegrationTest
  test "only global application admin can reach storefront administration" do
    get storefront_admin_products_path
    assert_response :not_found

    sign_in(users(:confirmed))
    get storefront_admin_products_path
    assert_response :not_found

    delete destroy_user_session_path
    sign_in(users(:admin))
    get storefront_admin_products_path
    assert_response :success
    get storefront_admin_orders_path
    assert_response :success
    get storefront_admin_payment_events_path
    assert_response :success
  end

  test "admin creates products without unsafe availability or inventory mass assignment" do
    sign_in(users(:admin))
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    post storefront_admin_products_path, params: { product: {
      name: "Admin download", slug: "admin-download", sku: "ADMIN-DL",
      description: "Digital file", price_cents: "1200", currency: "usd", position: "1",
      active: "false", inventory_quantity: "999", admin: "true"
    } }
    product = Foundation::Storefront::Product.find_by!(slug: "admin-download")
    assert_redirected_to storefront_admin_product_path(product)
    assert_predicate product, :active?
    assert_equal 0, product.inventory_quantity
    event = output.string.lines.find { |line| line.include?(Foundation::Admin::Audit::EVENT_NAME) }
    payload = JSON.parse(event[event.index("{")..])
    assert_equal product.id, payload.fetch("subject_id")

    post set_availability_storefront_admin_product_path(product), params: { active: "maybe" }
    assert_redirected_to storefront_admin_product_path(product)
    assert_predicate product.reload, :active?
  ensure
    Rails.logger = original_logger
  end

  test "admin CSV import is bounded and reports rows" do
    sign_in(users(:admin))
    upload = fixture_file_upload("storefront_products.csv", "text/csv")
    post import_storefront_admin_products_path, params: { csv: upload }
    assert_response :success
    assert_select "h1", text: "Product import result"
    assert_select "td", text: "created"
    assert_equal 1_250, Foundation::Storefront::Product.find_by!(slug: "imported-download").price_cents
  end

  test "partial CSV import audit records only counts and partial outcome" do
    sign_in(users(:admin))
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    upload = fixture_file_upload("storefront_products_partial.csv", "text/csv")
    post import_storefront_admin_products_path, params: { csv: upload, secret: "CSV-SECRET" }
    assert_response :success
    event = output.string.lines.find { |line| line.include?(Foundation::Admin::Audit::EVENT_NAME) }
    payload = JSON.parse(event[event.index("{")..])
    assert_equal "partial", payload.fetch("outcome")
    assert_equal({ "created" => 1, "updated" => 0, "errors" => 1 }, payload.fetch("details"))
    assert_equal "Foundation::Storefront::Product", payload.fetch("subject_type")
    assert_nil payload["subject_id"]
    assert_not_includes event, "CSV-SECRET"
  ensure
    Rails.logger = original_logger
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "correct horse battery" } }
    assert_response :redirect
  end
end
