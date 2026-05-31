require "digest"
require "erb"

module Providers
  class SandboxNfseClient
    TimeoutError = Class.new(StandardError)
    AuthenticationError = Class.new(StandardError)
    ValidationError = Class.new(StandardError)
    DuplicateRequestError = Class.new(StandardError)
    UnavailableError = Class.new(StandardError)
    ContractError = Class.new(StandardError)

    Result = Struct.new(
      :provider_name,
      :environment,
      :operation,
      :status,
      :provider_invoice_number,
      :provider_verification_code,
      :provider_protocol,
      :xml_url,
      :pdf_url,
      :xml_body,
      :pdf_body,
      :xml_sha256,
      :pdf_sha256,
      :issued_at,
      :cancelled_at,
      :message,
      :raw_metadata,
      keyword_init: true
    ) do
      def to_h
        super.except(:xml_body, :pdf_body).compact
      end
    end

    Document = Struct.new(
      :provider_name,
      :environment,
      :document_type,
      :body,
      :content_type,
      :filename,
      :sha256,
      :source_url,
      :retrieved_at,
      :raw_metadata,
      keyword_init: true
    ) do
      def to_h
        super.except(:body).compact
      end
    end

    def self.issue(invoice, idempotency_key: nil, environment: default_environment(invoice))
      raise TimeoutError, "Sandbox provider timed out" if invoice.service_description.include?("[provider_timeout]")

      protocol = "PROTO-#{invoice.public_id}-#{invoice.lock_version}"

      if invoice.service_description.include?("[provider_reject]")
        return Result.new(
          provider_name: provider_name,
          environment: environment,
          operation: "issue",
          status: "rejected",
          provider_protocol: protocol,
          message: "Provider rejected the service invoice payload.",
          raw_metadata: { idempotency_key: idempotency_key }
        )
      end

      verification_code = SecureRandom.alphanumeric(12).upcase
      xml_body = issue_xml(invoice, protocol, verification_code)
      pdf_body = issue_pdf(invoice, protocol, verification_code)

      Result.new(
        provider_name: provider_name,
        environment: environment,
        operation: "issue",
        status: "issued",
        provider_invoice_number: "NFSE-#{invoice.public_id}",
        provider_verification_code: verification_code,
        provider_protocol: protocol,
        xml_url: "https://storage.local/fiscalbridge/#{invoice.public_id}.xml",
        pdf_url: "https://storage.local/fiscalbridge/#{invoice.public_id}.pdf",
        xml_body: xml_body,
        pdf_body: pdf_body,
        xml_sha256: Digest::SHA256.hexdigest(xml_body),
        pdf_sha256: Digest::SHA256.hexdigest(pdf_body),
        issued_at: Time.current,
        message: "Issued successfully",
        raw_metadata: { idempotency_key: idempotency_key }
      )
    end

    def self.cancel(invoice, idempotency_key: nil, reason: invoice.cancellation_reason, environment: default_environment(invoice))
      protocol = "CANCEL-#{invoice.public_id}-#{invoice.lock_version}"

      if reason.to_s.include?("[provider_reject]")
        return Result.new(
          provider_name: provider_name,
          environment: environment,
          operation: "cancel",
          status: "cancellation_failed",
          provider_protocol: protocol,
          message: "Provider refused the cancellation request.",
          raw_metadata: { idempotency_key: idempotency_key, reason: reason }
        )
      end

      Result.new(
        provider_name: provider_name,
        environment: environment,
        operation: "cancel",
        status: "cancelled",
        provider_protocol: protocol,
        cancelled_at: Time.current,
        message: "Cancelled successfully",
        raw_metadata: { idempotency_key: idempotency_key, reason: reason }
      )
    end

    def self.fetch_status(invoice, environment: default_environment(invoice))
      Result.new(
        provider_name: provider_name,
        environment: environment,
        operation: "fetch_status",
        status: invoice.status,
        provider_invoice_number: invoice.provider_invoice_number,
        provider_verification_code: invoice.provider_verification_code,
        provider_protocol: invoice.provider_protocol,
        xml_url: invoice.xml_url,
        pdf_url: invoice.pdf_url,
        issued_at: invoice.issued_at,
        cancelled_at: invoice.cancelled_at,
        message: "Current sandbox status is #{invoice.status}",
        raw_metadata: { lock_version: invoice.lock_version }
      )
    end

    def self.status(invoice)
      fetch_status(invoice)
    end

    def self.download_xml(invoice, environment: default_environment(invoice))
      protocol = invoice.provider_protocol.presence || "PROTO-#{invoice.public_id}-#{invoice.lock_version}"
      verification_code = invoice.provider_verification_code.presence || "PENDING"
      body = issue_xml(invoice, protocol, verification_code)

      Document.new(
        provider_name: provider_name,
        environment: environment,
        document_type: "xml",
        body: body,
        content_type: "application/xml",
        filename: "#{invoice.public_id}.xml",
        sha256: Digest::SHA256.hexdigest(body),
        source_url: invoice.xml_url,
        retrieved_at: Time.current,
        raw_metadata: { provider_protocol: protocol }
      )
    end

    def self.download_pdf(invoice, environment: default_environment(invoice))
      protocol = invoice.provider_protocol.presence || "PROTO-#{invoice.public_id}-#{invoice.lock_version}"
      verification_code = invoice.provider_verification_code.presence || "PENDING"
      body = issue_pdf(invoice, protocol, verification_code)

      Document.new(
        provider_name: provider_name,
        environment: environment,
        document_type: "pdf",
        body: body,
        content_type: "application/pdf",
        filename: "#{invoice.public_id}.pdf",
        sha256: Digest::SHA256.hexdigest(body),
        source_url: invoice.pdf_url,
        retrieved_at: Time.current,
        raw_metadata: { provider_protocol: protocol }
      )
    end

    def self.provider_name
      "sandbox_nfse"
    end

    def self.default_environment(invoice)
      invoice.fiscal_profile&.environment || "sandbox"
    end

    def self.issue_xml(invoice, protocol, verification_code)
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <nfse>
          <numero>NFSE-#{ERB::Util.html_escape(invoice.public_id)}</numero>
          <codigo_verificacao>#{ERB::Util.html_escape(verification_code)}</codigo_verificacao>
          <protocolo>#{ERB::Util.html_escape(protocol)}</protocolo>
          <tomador documento="#{ERB::Util.html_escape(invoice.customer.document_number)}">
            #{ERB::Util.html_escape(invoice.customer.legal_name)}
          </tomador>
          <servico codigo="#{ERB::Util.html_escape(invoice.service_code)}">
            #{ERB::Util.html_escape(invoice.service_description)}
          </servico>
          <valor_centavos>#{invoice.amount_cents}</valor_centavos>
        </nfse>
      XML
    end

    def self.issue_pdf(invoice, protocol, verification_code)
      <<~PDF
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Count 1 /Kids [3 0 R] >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>
        endobj
        4 0 obj
        << /Length 116 >>
        stream
        BT
        /F1 12 Tf
        72 720 Td
        (FiscalBridge NFSe #{invoice.public_id} #{protocol} #{verification_code}) Tj
        ET
        endstream
        endobj
        %%EOF
      PDF
    end
  end
end
