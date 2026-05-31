require "test_helper"

class RateLimitingAndMetricsTest < ActionDispatch::IntegrationTest
  test "rate limits repeated requests by token" do
    previous_limit = ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"]
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = "2"
    bootstrap = bootstrap_organization(slug: unique_slug("rate"))
    token = bootstrap.dig("owner", "api_token")

    2.times { get "/v1/organization", headers: auth_headers(token) }

    get "/v1/organization", headers: auth_headers(token)

    assert_response :too_many_requests
    assert_equal "rate_limited", json_response.dig("error", "code")
    assert response.headers["Retry-After"].present?
  ensure
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = previous_limit
  end

  test "exports prometheus metrics with correlation headers" do
    get "/up", headers: { "HTTP_X_CORRELATION_ID" => "metrics-correlation" }
    assert_response :success

    get "/metrics", headers: { "HTTP_X_CORRELATION_ID" => "metrics-correlation" }

    assert_response :success
    assert_includes response.body, "fiscalbridge_http_requests_total"
    assert_equal "metrics-correlation", response.headers["X-Correlation-ID"]
  end

  test "aggregates request duration histograms without retaining raw samples" do
    Observability::MetricsRegistry.record(method: "GET", path: "/up", status: 200, duration: 0.02)
    Observability::MetricsRegistry.record(method: "GET", path: "/up", status: 200, duration: 0.40)
    Observability::MetricsRegistry.record(method: "GET", path: "/up", status: 200, duration: 6.00)

    metrics = Observability::MetricsRegistry.render

    assert_includes metrics, 'fiscalbridge_http_request_duration_seconds_bucket{method="GET",path="/up",status="200",le="0.05"} 1'
    assert_includes metrics, 'fiscalbridge_http_request_duration_seconds_bucket{method="GET",path="/up",status="200",le="+Inf"} 3'
    assert_includes metrics, 'fiscalbridge_http_request_duration_seconds_count{method="GET",path="/up",status="200"} 3'
    assert_nil Observability::MetricsRegistry.instance_variable_get(:@http_durations)
  end
end
