require "digest"

module Security
  class RateLimiter
    WINDOW_SECONDS = 60

    @mutex = Mutex.new
    @override_namespace = nil

    class << self
      def check!(identifier)
        now = Time.current.to_i
        count = increment_counter(cache_key(identifier, now / WINDOW_SECONDS))
        return if count <= limit

        raise RateLimitExceeded.new(retry_after: retry_after(now))
      end

      def limit
        ENV.fetch("RATE_LIMIT_REQUESTS_PER_MINUTE", 120).to_i
      end

      def reset!
        @mutex.synchronize do
          @override_namespace = Rails.env.test? ? "test-#{SecureRandom.hex(8)}" : nil
        end
      end

      private

      def namespace
        @mutex.synchronize do
          @override_namespace || ENV.fetch("RATE_LIMIT_NAMESPACE", Rails.application.class.module_parent_name.underscore)
        end
      end

      def cache_key(identifier, bucket)
        digest = Digest::SHA256.hexdigest(identifier.to_s)
        "rate-limit:v2:#{namespace}:#{digest}:#{bucket}"
      end

      def increment_counter(key)
        Rails.cache.increment(key, 1, expires_in: WINDOW_SECONDS + 5) || initialize_counter(key)
      end

      def initialize_counter(key)
        Rails.cache.write(key, 1, expires_in: WINDOW_SECONDS + 5)
        1
      end

      def retry_after(now)
        [ WINDOW_SECONDS - (now % WINDOW_SECONDS), 1 ].max
      end
    end
  end
end
