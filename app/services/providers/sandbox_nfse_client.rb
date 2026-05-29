module Providers
  class SandboxNfseClient
    TimeoutError = Class.new(StandardError)
    Result = Struct.new(
      :status,
      :provider_invoice_number,
      :provider_verification_code,
      :provider_protocol,
      :xml_url,
      :pdf_url,
      :issued_at,
      :cancelled_at,
      :message,
      keyword_init: true
    )

    def self.issue(invoice)
      raise TimeoutError, "Sandbox provider timed out" if invoice.service_description.include?("[provider_timeout]")

      protocol = "PROTO-#{invoice.public_id}-#{invoice.lock_version}"

      if invoice.service_description.include?("[provider_reject]")
        return Result.new(
          status: "rejected",
          provider_protocol: protocol,
          message: "Provider rejected the service invoice payload."
        )
      end

      Result.new(
        status: "issued",
        provider_invoice_number: "NFSE-#{invoice.public_id}",
        provider_verification_code: SecureRandom.alphanumeric(12).upcase,
        provider_protocol: protocol,
        xml_url: "https://storage.local/fiscalbridge/#{invoice.public_id}.xml",
        pdf_url: "https://storage.local/fiscalbridge/#{invoice.public_id}.pdf",
        issued_at: Time.current,
        message: "Issued successfully"
      )
    end

    def self.cancel(invoice)
      protocol = "CANCEL-#{invoice.public_id}-#{invoice.lock_version}"

      if invoice.cancellation_reason.to_s.include?("[provider_reject]")
        return Result.new(
          status: "cancellation_failed",
          provider_protocol: protocol,
          message: "Provider refused the cancellation request."
        )
      end

      Result.new(
        status: "cancelled",
        provider_protocol: protocol,
        cancelled_at: Time.current,
        message: "Cancelled successfully"
      )
    end

    def self.status(invoice)
      Result.new(
        status: invoice.status,
        provider_invoice_number: invoice.provider_invoice_number,
        provider_verification_code: invoice.provider_verification_code,
        provider_protocol: invoice.provider_protocol,
        xml_url: invoice.xml_url,
        pdf_url: invoice.pdf_url,
        issued_at: invoice.issued_at,
        cancelled_at: invoice.cancelled_at,
        message: "Current sandbox status is #{invoice.status}"
      )
    end
  end
end
