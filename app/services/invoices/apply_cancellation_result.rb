module Invoices
  class ApplyCancellationResult
    def self.call!(invoice:, provider_request:, result:)
      ActiveRecord::Base.transaction do
        if result.status == "cancelled"
          invoice.update!(
            status: "cancelled",
            provider_protocol: result.provider_protocol,
            cancelled_at: result.cancelled_at
          )
        else
          invoice.update!(
            status: "cancellation_failed",
            rejection_reason: result.message,
            provider_protocol: result.provider_protocol
          )
        end

        provider_request.update!(
          status: "succeeded",
          response_payload: result.to_h,
          responded_at: Time.current
        )

        action = invoice.cancelled? ? "service_invoice.cancelled" : "service_invoice.cancellation_failed"

        Auditing::Logger.log!(
          organization: invoice.organization,
          membership: nil,
          auditable: invoice,
          action: action,
          metadata: { provider_request_id: provider_request.id, provider_protocol: invoice.provider_protocol }
        )

        Events::Publisher.publish!(
          organization: invoice.organization,
          aggregate: invoice,
          event_type: action,
          payload: { service_invoice: invoice.as_api_json, provider_request_id: provider_request.id }
        )
      end

      invoice
    end
  end
end
