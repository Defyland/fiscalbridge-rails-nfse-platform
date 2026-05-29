class PlatformController < ActionController::API
  after_action :set_observability_headers

  def live
    render json: { status: "ok", service: "fiscalbridge-api", time: Time.current.iso8601 }
  end

  def ready
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: {
      status: "ready",
      checks: {
        database: "ok",
        jobs: Rails.application.config.active_job.queue_adapter.to_s
      }
    }
  rescue StandardError => error
    render json: {
      status: "degraded",
      error: error.message
    }, status: :service_unavailable
  end

  def metrics
    render plain: Observability::MetricsRegistry.render,
           content_type: "text/plain; version=0.0.4"
  end

  private

  def set_observability_headers
    response.set_header("X-Request-ID", Current.request_id || request.request_id)
    correlation_id = Current.correlation_id ||
                     request.get_header("HTTP_X_CORRELATION_ID") ||
                     request.headers["X-Correlation-ID"]
    response.set_header("X-Correlation-ID", correlation_id) if correlation_id.present?
  end
end
