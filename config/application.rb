require_relative "boot"

require "rails/all"
require_relative "../lib/foundation/runtime_config"
require_relative "../lib/foundation"
require_relative "../lib/foundation/noindex_middleware"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VelaFoundation
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Product identity and foundation-wide settings (config/foundation.yml),
    # readable with string or symbol keys as Rails.configuration.x.foundation.
    config.x.foundation = config_for(:foundation).with_indifferent_access
    config.x.runtime_config = Foundation::RuntimeConfig.new(
      environment: ENV,
      foundation: config.x.foundation,
      rails_environment: Rails.env
    )

    # This wrapper sits outside ActionDispatch::Static and exception handling,
    # so every Rails-controlled hosted-preview response receives noindex.
    config.middleware.insert_before 0, Foundation::NoindexMiddleware

    # Disable Active Storage's generic public/direct-upload routes. Uploads are
    # ordinary authenticated multipart fields; catalog images (when present)
    # are served only through a bounded product endpoint.
    config.active_storage.draw_routes = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
