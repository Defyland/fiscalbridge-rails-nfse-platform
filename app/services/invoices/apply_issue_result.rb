module Invoices
  class ApplyIssueResult
    def self.call!(invoice:, provider_request:, result:)
      ActiveRecord::Base.transaction do
        if result.status == "issued"
          invoice.update!(
            status: "issued",
            provider_invoice_number: result.provider_invoice_number,
            provider_verification_code: result.provider_verification_code,
            provider_protocol: result.provider_protocol,
            xml_url: result.xml_url,
            pdf_url: result.pdf_url,
            issued_at: result.issued_at,
            rejection_reason: nil
          )
        else
          invoice.update!(
            status: "rejected",
            provider_protocol: result.provider_protocol,
            rejection_reason: result.message
          )
        end

        provider_request.update!(
          status: "succeeded",
          response_payload: result.to_h,
          responded_at: Time.current
        )

        action = invoice.issued? ? "service_invoice.issued" : "service_invoice.rejected"

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
