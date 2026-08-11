require "test_helper"

# Production enables ActionDispatch::HostAuthorization from the runtime
# snapshot (config/environments/production.rb). The test environment does
# not load that file, so this builds the same middleware + host list the
# production boot path would install and probes it against a tiny rack app
# (never Rails.application — calling the full stack from a unit test races
# parallel workers).
class HostAuthorizationTest < ActiveSupport::TestCase
  OK = ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "ok" ] ] }.freeze

  test "unrecognised Host is refused while the health check still answers" do
    domain = Rails.configuration.x.foundation.fetch(:domain)
    app = host_authorization_app(
      Foundation.runtime_config.allowed_request_hosts(foundation_domain: domain)
    )

    assert_equal 403, request_status(app, "evil.invalid", "/")
    assert_equal 200, request_status(app, "evil.invalid", "/up")
    assert_equal 200, request_status(app, domain, "/")
    assert_equal 200, request_status(app, "www.#{domain}", "/")
  end

  test "both probe endpoints stay reachable by internal name" do
    domain = Rails.configuration.x.foundation.fetch(:domain)
    app = host_authorization_app(
      Foundation.runtime_config.allowed_request_hosts(foundation_domain: domain)
    )

    # Allgood is mounted at /healthcheck (config/routes.rb) and documented as
    # a probe target alongside /up in docs/HOSTED_RUNTIME.md. Both are hit by
    # IP or internal hostname, so both must bypass host authorization.
    assert_equal 200, request_status(app, "10.0.0.7", "/up")
    assert_equal 200, request_status(app, "10.0.0.7", "/healthcheck")
    assert_equal 403, request_status(app, "10.0.0.7", "/billing")
  end

  test "association files remain reachable on the product domain" do
    domain = Rails.configuration.x.foundation.fetch(:domain)
    app = host_authorization_app(
      Foundation.runtime_config.allowed_request_hosts(foundation_domain: domain)
    )

    # Deep-link verifiers fetch these on the public product host. They are not
    # health probes and must not rely on the host-authorization exclude list;
    # they simply need the product domain to be allowed (which it is).
    assert_equal 200, request_status(app, domain, "/.well-known/apple-app-site-association")
    assert_equal 200, request_status(app, domain, "/.well-known/assetlinks.json")
    assert_equal 403, request_status(app, "evil.invalid", "/.well-known/apple-app-site-association")
    assert_equal 403, request_status(app, "evil.invalid", "/.well-known/assetlinks.json")
  end


  test "hosted preview allows only its runtime-assigned APP_HOST" do
    with_env(
      "VELA_HOLODEX_PREVIEW" => "1",
      "APP_HOST" => "https://slug.demo.holodex.test"
    ) do
      app = host_authorization_app(
        Foundation.runtime_config.allowed_request_hosts(
          foundation_domain: Rails.configuration.x.foundation.fetch(:domain)
        )
      )

      assert_equal 200, request_status(app, "slug.demo.holodex.test", "/")
      assert_equal 403, request_status(app, "evil.invalid", "/")
      assert_equal 200, request_status(app, "evil.invalid", "/up")
    end
  end

  private

  def host_authorization_app(hosts)
    ActionDispatch::HostAuthorization.new(
      OK,
      hosts,
      exclude: Foundation::RuntimeConfig::HEALTH_PROBE_PATHS
    )
  end

  def request_status(app, host, path)
    env = Rack::MockRequest.env_for("http://#{host}#{path}", "HTTP_HOST" => host)
    status, = app.call(env)
    status
  end
end
