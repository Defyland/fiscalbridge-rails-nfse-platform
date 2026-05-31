require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = false

  config.action_controller.perform_caching = false
  config.cache_store = :solid_cache_store
  config.active_storage.service = :local
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = false
  config.active_record.query_log_tags_enabled = false
  config.active_job.queue_adapter = :solid_queue
  config.action_controller.raise_on_missing_callback_actions = true
end
