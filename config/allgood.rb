# Health checks served by the Allgood engine at /healthcheck (mounted in
# config/routes.rb). The page answers 200 only when every check passes and
# 503 otherwise, so a single URL tells monitors whether the app is healthy.

runtime_config = Foundation.runtime_config

check "Hosted preview is #{runtime_config.preview? ? 'active' : 'inactive'}" do
  make_sure true, "Runtime mode is reported from the immutable boot configuration"
end

check "Canonical domain is configured" do
  domain = Rails.configuration.x.foundation[:domain]
  placeholder = domain.blank? || domain == "example.com"
  # Outside hosted preview, config.hosts is built from this domain, so an
  # unstamped template would answer 403 to every real request. Preview gets
  # its hostname from APP_HOST instead and is unaffected.
  make_sure !(runtime_config.production? && !runtime_config.preview? && placeholder),
    "Set the foundation.yml domain (bin/rename) — production refuses every request whose Host does not match it"
end

check "Mail mode: #{runtime_config.mail_mode(provider: Rails.application.config.action_mailer.delivery_method)}" do
  # Reporting mail mode must never attempt a network delivery.
  make_sure Rails.application.config.action_mailer.delivery_method.present?,
    "Action Mailer should have an explicit delivery provider"
end

check "Storage mode: #{runtime_config.storage_mode}" do
  service = ActiveStorage::Blob.service
  safe_production_service = !service.is_a?(ActiveStorage::Service::DiskService)
  make_sure runtime_config.production_storage_configured? &&
    (!runtime_config.production? || runtime_config.preview? || safe_production_service),
    "Production requires ACTIVE_STORAGE_SERVICE to name a configured non-disk cloud service"
end

# foundation:module storefront
check "Storefront simulator is #{Foundation.storefront_simulator? ? 'active' : 'inactive'}" do
  make_sure true, "Payment mode is reported without contacting Stripe"
end
# /foundation:module storefront

check "Solid Queue runs #{runtime_config.queue_mode}" do
  make_sure true, "Queue process topology is reported from SOLID_QUEUE_IN_PUMA"
end

check "Database is reachable and answers queries" do
  answer = ApplicationRecord.connection_pool.with_connection do |connection|
    connection.select_value("SELECT 1")
  end
  make_sure answer == 1, "A trivial SELECT should return 1"
end

check "Database migrations are all applied" do
  # check_all_pending! raises when any migration is pending, across every
  # configured database for this environment.
  make_sure ActiveRecord::Migration.check_all_pending!.nil?
end

check "Job queue is live" do
  adapter = ActiveJob::Base.queue_adapter
  if adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter)
    cutoff = SolidQueue.process_alive_threshold.ago
    make_sure SolidQueue::Process.where(last_heartbeat_at: cutoff..).exists?,
      "At least one Solid Queue process should have sent a heartbeat since #{cutoff}"
  else
    # In-process adapters (test, async, inline) execute jobs without a
    # separate worker, so a configured adapter is all that liveness means.
    make_sure adapter.present?, "An Active Job queue adapter should be configured"
  end
end

check "Configured storage is writable" do
  service = ActiveStorage::Blob.service
  probe_key = "foundation-healthcheck-#{SecureRandom.uuid}"
  written = false
  begin
    service.upload(probe_key, StringIO.new("probe"))
    written = service.exist?(probe_key)
  ensure
    service.delete(probe_key)
  end
  make_sure written, "The #{service.class.name.demodulize} storage service should accept a small write"
end

# foundation:module storefront
unless Rails.env.test?
  check "Enabled storefront payment configuration is ready" do
    result = Foundation::Storefront::Readiness.call
    make_sure result.ready?, result.errors.join("; ")
  end
end
# /foundation:module storefront

disk_threshold = Rails.configuration.x.foundation.fetch(:healthcheck_disk_usage_percent_max, 90).to_i
check "Disk usage is below #{disk_threshold}%" do
  usage = Foundation::HostResources.disk_usage_percent
  if usage.nil?
    # Prefer a soft pass over a hard fail when the platform hides capacity
    # figures (restricted containers, unusual hosts).
    make_sure true, "Disk usage is not exposed on this platform; probe skipped"
  else
    make_sure usage < disk_threshold, "Disk usage at #{usage}% (threshold #{disk_threshold}%)"
  end
end

memory_threshold = Rails.configuration.x.foundation.fetch(:healthcheck_memory_usage_percent_max, 90).to_i
check "Memory usage is below #{memory_threshold}%" do
  usage = Foundation::HostResources.memory_usage_percent
  if usage.nil?
    make_sure true, "Memory usage is not exposed on this platform; probe skipped"
  else
    make_sure usage < memory_threshold, "Memory usage at #{usage}% (threshold #{memory_threshold}%)"
  end
end
