module V1
  class ProviderCallbacksController < ActionController::API
    MissingProviderCallbackToken = Class.new(StandardError)
    InvalidProviderCallback = Class.new(StandardError)
    SUPPORTED_STATUSES = %w[issued cancelled].freeze

    before_action :verify_provider_token!
    after_action :set_observability_headers

    rescue_from ActionController::ParameterMissing do |error|
      render json: { error: { code: "missing_parameter", message: error.message } }, status: :bad_request
    end

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: { code: "not_found", message: "Provider invoice was not found." } }, status: :not_found
    end

    rescue_from MissingProviderCallbackToken do
      render json: {
        error: {
          code: "provider_callback_token_not_configured",
          message: "Provider callback token is not configured."
        }
      }, status: :service_unavailable
    end

    rescue_from InvalidProviderCallback do |error|
      render json: { error: { code: "invalid_provider_callback", message: error.message } },
             status: :unprocessable_entity
    end

    def nfse
      provider_request = Providers::ApplyCallback.call!(payload: callback_payload)

      render json: {
        accepted: true,
        duplicate: provider_request.duplicate?,
        provider_request_id: provider_request.id
      }, status: :accepted
    end

    private

    def callback_payload
      payload = params.require(:callback).permit(
        :callback_id,
        :provider_invoice_number,
        :status,
        :provider_protocol
      ).to_h.symbolize_keys

      %i[callback_id provider_invoice_number status].each do |key|
        raise ActionController::ParameterMissing, key if payload[key].blank?
      end

      unless SUPPORTED_STATUSES.include?(payload.fetch(:status))
        raise InvalidProviderCallback, "Unsupported provider callback status #{payload.fetch(:status)}."
      end

      payload
    end

    def verify_provider_token!
      expected = provider_callback_token
      token = request.headers["X-Provider-Token"].to_s
      return if token.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(token, expected)

      render json: { error: { code: "unauthorized", message: "Invalid provider callback token." } },
             status: :unauthorized
    end

    def provider_callback_token
      configured_token = ENV["PROVIDER_CALLBACK_TOKEN"].presence
      return configured_token if configured_token.present?
      return "local-provider-token" unless Rails.env.production?

      raise MissingProviderCallbackToken
    end

    def set_observability_headers
      response.set_header("X-Request-ID", Current.request_id || request.request_id)
      correlation_id = Current.correlation_id ||
                       request.get_header("HTTP_X_CORRELATION_ID") ||
                       request.headers["X-Correlation-ID"]
      response.set_header("X-Correlation-ID", correlation_id) if correlation_id.present?
    end
  end
end
