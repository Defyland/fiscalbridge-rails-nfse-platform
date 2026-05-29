module Middleware
  class RequestContext
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      request_id = request.request_id
      correlation_id = request.get_header("HTTP_X_CORRELATION_ID").presence ||
                       request.headers["X-Correlation-ID"].presence ||
                       SecureRandom.uuid

      Current.request_id = request_id
      Current.correlation_id = correlation_id
      Current.remote_ip = request.remote_ip
      Current.user_agent = request.user_agent

      status, headers, response = @app.call(env)
      headers["X-Request-ID"] ||= request_id if request_id.present?
      headers["X-Correlation-ID"] = correlation_id if correlation_id.present?
      headers["X-Trace-ID"] = trace_id if trace_id

      [ status, headers, response ]
    ensure
      Current.reset
    end

    private

    def trace_id
      span = OpenTelemetry::Trace.current_span
      return if span.nil?

      context = span.context
      return if context.nil? || !context.valid?

      context.hex_trace_id
    end
  end
end
