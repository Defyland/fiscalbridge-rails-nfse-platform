otel_exporter = ENV["OTEL_TRACES_EXPORTER"].to_s.strip
otel_endpoint = ENV.values_at(
  "OTEL_EXPORTER_OTLP_ENDPOINT",
  "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
).compact_blank.first

if otel_endpoint.present? || (otel_exporter.present? && otel_exporter != "none")
  require "opentelemetry/sdk"

  OpenTelemetry::SDK.configure do |config|
    config.service_name = "fiscalbridge-api"
    config.use "OpenTelemetry::Instrumentation::Rack"
    config.use "OpenTelemetry::Instrumentation::ActionPack"
    config.use "OpenTelemetry::Instrumentation::ActiveRecord"
    config.use "OpenTelemetry::Instrumentation::ActiveJob"
    config.use "OpenTelemetry::Instrumentation::ActiveSupport"
  end
end
