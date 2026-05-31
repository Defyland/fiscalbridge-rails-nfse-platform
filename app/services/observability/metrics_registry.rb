module Observability
  class MetricsRegistry
    HTTP_BUCKETS = [ 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0 ].freeze

    @mutex = Mutex.new
    @http_totals = Hash.new(0)
    @http_duration_bucket_counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @http_duration_sums = Hash.new(0.0)
    @http_duration_counts = Hash.new(0)
    @outbound_totals = Hash.new(0)

    class << self
      def record(method:, path:, status:, duration:)
        labels = [ method.to_s.upcase, normalize_path(path), status.to_i ]

        @mutex.synchronize do
          @http_totals[labels] += 1
          @http_duration_counts[labels] += 1
          @http_duration_sums[labels] += duration
          HTTP_BUCKETS.each do |bucket|
            @http_duration_bucket_counts[labels][bucket] += 1 if duration <= bucket
          end
        end
      end

      def record_outbound(event_type:, status:)
        @mutex.synchronize do
          @outbound_totals[[ event_type, status.to_s ]] += 1
        end
      end

      def render
        snapshot = nil

        @mutex.synchronize do
          snapshot = {
            http_totals: @http_totals.deep_dup,
            http_duration_bucket_counts: @http_duration_bucket_counts.deep_dup,
            http_duration_sums: @http_duration_sums.deep_dup,
            http_duration_counts: @http_duration_counts.deep_dup,
            outbound_totals: @outbound_totals.deep_dup
          }
        end

        build_http_metrics(
          snapshot[:http_totals],
          snapshot[:http_duration_bucket_counts],
          snapshot[:http_duration_sums],
          snapshot[:http_duration_counts]
        ) +
          build_outbound_metrics(snapshot[:outbound_totals])
      end

      def reset!
        @mutex.synchronize do
          @http_totals.clear
          @http_duration_bucket_counts.clear
          @http_duration_sums.clear
          @http_duration_counts.clear
          @outbound_totals.clear
        end
      end

      private

      def build_http_metrics(http_totals, http_duration_bucket_counts, http_duration_sums, http_duration_counts)
        lines = []
        lines << "# HELP fiscalbridge_http_requests_total Total HTTP requests processed."
        lines << "# TYPE fiscalbridge_http_requests_total counter"

        http_totals.sort.each do |(method, path, status), count|
          lines << %(fiscalbridge_http_requests_total{method="#{method}",path="#{path}",status="#{status}"} #{count})
        end

        lines << "# HELP fiscalbridge_http_request_duration_seconds HTTP request duration histogram."
        lines << "# TYPE fiscalbridge_http_request_duration_seconds histogram"

        http_duration_counts.sort.each do |(method, path, status), count|
          labels = [ method, path, status ]
          HTTP_BUCKETS.each do |bucket|
            bucket_count = http_duration_bucket_counts.fetch(labels, {}).fetch(bucket, 0)
            lines << %(fiscalbridge_http_request_duration_seconds_bucket{method="#{method}",path="#{path}",status="#{status}",le="#{bucket}"} #{bucket_count})
          end

          lines << %(fiscalbridge_http_request_duration_seconds_bucket{method="#{method}",path="#{path}",status="#{status}",le="+Inf"} #{count})
          lines << %(fiscalbridge_http_request_duration_seconds_sum{method="#{method}",path="#{path}",status="#{status}"} #{http_duration_sums.fetch(labels, 0.0).round(6)})
          lines << %(fiscalbridge_http_request_duration_seconds_count{method="#{method}",path="#{path}",status="#{status}"} #{count})
        end

        lines.join("\n") + "\n"
      end

      def build_outbound_metrics(outbound_totals)
        lines = []
        lines << "# HELP fiscalbridge_outbound_events_total Total outbound domain events."
        lines << "# TYPE fiscalbridge_outbound_events_total counter"

        outbound_totals.sort.each do |(event_type, status), count|
          lines << %(fiscalbridge_outbound_events_total{event_type="#{event_type}",status="#{status}"} #{count})
        end

        lines.join("\n") + "\n"
      end

      def normalize_path(path)
        path.to_s
            .gsub(%r{/memberships/\d+}, "/memberships/:id")
            .gsub(%r{/fiscal_profiles/\d+}, "/fiscal_profiles/:id")
            .gsub(%r{/customers/\d+}, "/customers/:id")
            .gsub(%r{/service_invoices/[^/]+}, "/service_invoices/:id")
      end
    end
  end
end
