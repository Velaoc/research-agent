# frozen_string_literal: true

# Invoked by the Docker test stage after a production db:prepare using only
# DATABASE_URL. It exercises every durable Rails adapter against that one
# prepared database instead of merely comparing configuration strings.

required_tables = %w[
  solid_cache_entries
  solid_cable_messages
  solid_queue_jobs
  users
]
connection = ApplicationRecord.connection
missing = required_tables - connection.data_sources
raise "single database is missing tables: #{missing.join(', ')}" if missing.any?

class FoundationSingleDatabaseProbeJob < ApplicationJob
  def perform; end
end

job_count = SolidQueue::Job.count
FoundationSingleDatabaseProbeJob.perform_later
raise "Solid Queue did not persist an enqueued job" unless SolidQueue::Job.count == job_count + 1

cache_key = "foundation-single-database-#{SecureRandom.hex(8)}"
Rails.cache.write(cache_key, "ready")
raise "Solid Cache read/write failed" unless Rails.cache.read(cache_key) == "ready"
Rails.cache.delete(cache_key)

cable_count = SolidCable::Message.count
ActionCable.server.broadcast("foundation-single-database", { ready: true })
unless SolidCable::Message.count == cable_count + 1
  raise "Solid Cable did not persist a broadcast"
end

databases = [
  ApplicationRecord,
  SolidQueue::Record,
  SolidCache::Record,
  SolidCable::Record
].to_h do |record_class|
  database = record_class.connection.select_value("SELECT current_database()")
  [ record_class.name, database ]
end
unless databases.values.uniq.one?
  raise "runtime adapters did not share one database: #{databases.inspect}"
end

puts "single-database runtime verified: #{databases.values.first}"
