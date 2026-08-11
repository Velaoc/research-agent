require "active_support/core_ext/integer/time"

Rails.application.configure do
  runtime_config = Rails.application.config.x.runtime_config

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Hosted previews are deliberately local. A real production deploy names
  # its cloud service with ACTIVE_STORAGE_SERVICE; readiness rejects the
  # secret-free local fallback before traffic is accepted.
  config.active_storage.service = runtime_config.active_storage_service

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Wall-clock ceiling per request: abort anything that runs longer than 15s
  # so a stuck action cannot pin a Puma worker indefinitely.
  config.middleware.insert_after ActionDispatch::RequestId, Rack::Timeout, service_timeout: 15

  # Kamal-proxy and load balancers probe over plain HTTP inside the private
  # network. Skip the HTTPS redirect for those paths only — same set excluded
  # from host authorization below.
  config.ssl_options = { redirect: { exclude: Foundation::RuntimeConfig::HEALTH_PROBE_PATHS } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = {
    database: { writing: runtime_config.database_role(:queue) }
  }

  # The generated application's explicit provider is SMTP. Deploy-time SMTP
  # settings take priority; an offline hosted preview switches to the in-memory
  # test adapter. Every other mode surfaces delivery failures.
  config.action_mailer.delivery_method = runtime_config.mail_delivery_method(provider: :smtp)
  config.action_mailer.smtp_settings = runtime_config.smtp_settings if runtime_config.smtp?
  config.action_mailer.raise_delivery_errors = runtime_config.raise_delivery_errors?
  config.action_mailer.default_url_options = runtime_config.url_options

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS rebinding / Host-header protection. Allowed hosts come from the
  # validated runtime snapshot: the foundation.yml domain (and subdomains)
  # in ordinary production, or the runtime-assigned APP_HOST in hosted
  # preview. Load balancers probe /up by IP or internal name, so that
  # path is excluded.
  config.hosts = runtime_config.allowed_request_hosts(
    foundation_domain: Rails.configuration.x.foundation.fetch(:domain)
  )
  config.host_authorization = {
    exclude: Foundation::RuntimeConfig::HEALTH_PROBE_PATHS
  }
end
