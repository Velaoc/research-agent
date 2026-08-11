require "test_helper"

class IndependentAdminGateController < ActionController::Base
  include Foundation::AdminAccess

  def index
    head :ok
  end

  def current_user
    request.env["foundation.test_user"]
  end
end

class AdminControllerAuthorizationTest < ActionController::TestCase
  tests IndependentAdminGateController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { get "gate" => "independent_admin_gate#index" }
  end

  test "controller authorization independently rejects guests" do
    get :index
    assert_response :not_found
  end

  test "controller authorization independently rejects normal users" do
    @request.env["foundation.test_user"] = users(:confirmed)
    get :index
    assert_response :not_found
  end

  test "controller authorization independently accepts app admins" do
    @request.env["foundation.test_user"] = users(:admin)
    get :index
    assert_response :success
  end
end
