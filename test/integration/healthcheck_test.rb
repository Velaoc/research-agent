require "test_helper"

class HealthcheckTest < ActionDispatch::IntegrationTest
  test "healthcheck endpoint responds successfully" do
    get "/healthcheck"

    assert_response :success
  end

  test "healthcheck covers database, migrations, queue, and storage" do
    get "/healthcheck"

    assert_includes response.body, "Database is reachable and answers queries"
    assert_includes response.body, "Database migrations are all applied"
    assert_includes response.body, "Job queue is live"
    assert_includes response.body, "Configured storage is writable"
    assert_includes response.body, "Hosted preview is inactive"
    assert_includes response.body, "Mail mode: test application provider"
    assert_includes response.body, "Storage mode: test disk"
    # foundation:module storefront
    assert_includes response.body, "Storefront simulator is inactive"
    # /foundation:module storefront
    assert_includes response.body, "Solid Queue runs external worker"
    assert_includes response.body, "Disk usage is below"
    assert_includes response.body, "Memory usage is below"
  end
end
