module Providers
  class ApplyCallback
    def self.call!(payload:)
      invoice = ServiceInvoice.find_by!(
        provider_invoice_number: payload.fetch(:provider_invoice_number)
      )

      existing = invoice.provider_requests.find_by(idempotency_key: payload.fetch(:callback_id))
      return existing.tap { |request| request.status = "duplicate" } if existing

      ProviderRequest.create!(
        organization: invoice.organization,
        service_invoice: invoice,
        provider_name: "sandbox_nfse",
        action: "callback",
        status: "succeeded",
        request_payload: payload,
        response_payload: { accepted: true },
        responded_at: Time.current,
        correlation_id: Current.correlation_id || SecureRandom.uuid,
        idempotency_key: payload.fetch(:callback_id)
      ).tap do |provider_request|
        apply_status(invoice, provider_request, payload)
      end
    rescue ActiveRecord::RecordNotUnique
      invoice.provider_requests.find_by!(idempotency_key: payload.fetch(:callback_id))
    end

    def self.apply_status(invoice, provider_request, payload)
      status = payload.fetch(:status)

      ActiveRecord::Base.transaction do
        case status
        when "cancelled"
          invoice.update!(status: "cancelled", cancelled_at: Time.current)
        when "issued"
          invoice.update!(status: "issued", issued_at: invoice.issued_at || Time.current)
        end

        Auditing::Logger.log!(
          organization: invoice.organization,
          membership: nil,
          auditable: invoice,
          action: "service_invoice.provider_callback",
          metadata: { provider_request_id: provider_request.id, status: status }
        )
      end
    end
  end
end
