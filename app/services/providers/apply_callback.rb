module Providers
  class ApplyCallback
    def self.call!(payload:)
      invoice = ServiceInvoice.find_by!(
        provider_invoice_number: payload.fetch(:provider_invoice_number)
      )
      callback_id = payload.fetch(:callback_id)
      provider_request = nil
      duplicate = false

      ActiveRecord::Base.transaction do
        invoice.lock!

        existing = invoice.provider_requests.find_by(idempotency_key: callback_id)

        if existing
          provider_request = existing
          duplicate = true
        else
          provider_request = invoice.provider_requests.create!(
            organization: invoice.organization,
            provider_name: "sandbox_nfse",
            action: "callback",
            status: "succeeded",
            request_payload: payload,
            response_payload: { accepted: true },
            responded_at: Time.current,
            correlation_id: Current.correlation_id || SecureRandom.uuid,
            idempotency_key: callback_id
          )
          apply_status(invoice:, provider_request:, payload:)
        end
      end

      duplicate ? mark_duplicate(provider_request) : provider_request
    rescue ActiveRecord::RecordNotUnique
      mark_duplicate(invoice.provider_requests.find_by!(idempotency_key: callback_id))
    end

    def self.apply_status(invoice:, provider_request:, payload:)
      status = payload.fetch(:status)

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

    def self.mark_duplicate(provider_request)
      provider_request.tap do |request|
        request.status = "duplicate"
      end
    end
  end
end
