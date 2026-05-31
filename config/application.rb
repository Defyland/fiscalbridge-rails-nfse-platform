require_relative "boot"
require_relative "../app/middleware/middleware/request_context"
require_relative "../app/middleware/middleware/metrics"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FiscalBridgeRailsNfsePlatform
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
    config.active_job.queue_adapter = :solid_queue
    config.cache_store = :solid_cache_store
    config.active_storage.variant_processor = :disabled
    config.solid_queue.connects_to = { database: { writing: :primary } }
    config.solid_cache.connects_to = { database: { writing: :primary } }

    config.middleware.insert_before(0, Middleware::RequestContext)
    config.middleware.use(Middleware::Metrics)
  end
end
