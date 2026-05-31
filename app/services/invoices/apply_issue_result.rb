require "erb"
require "digest"
require "stringio"

module Invoices
  class ApplyIssueResult
    def self.call!(invoice:, provider_request:, result:)
      ActiveRecord::Base.transaction do
        if result.status == "issued"
          evidence_digests = attach_fiscal_evidence!(invoice, result)
          invoice.update!(
            status: "issued",
            provider_invoice_number: result.provider_invoice_number,
            provider_verification_code: result.provider_verification_code,
            provider_protocol: result.provider_protocol,
            xml_url: result.xml_url,
            pdf_url: result.pdf_url,
            xml_sha256: evidence_digests.fetch(:xml_sha256),
            pdf_sha256: evidence_digests.fetch(:pdf_sha256),
            evidence_recorded_at: Time.current,
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

    def self.attach_fiscal_evidence!(invoice, result)
      xml_body = result.xml_body.presence || xml_payload(invoice, result)
      pdf_body = result.pdf_body.presence || pdf_payload(invoice, result)
      xml_sha256 = Digest::SHA256.hexdigest(xml_body)
      pdf_sha256 = Digest::SHA256.hexdigest(pdf_body)

      verify_checksum!(xml_sha256, result.xml_sha256, "XML")
      verify_checksum!(pdf_sha256, result.pdf_sha256, "PDF")

      invoice.xml_file.attach(
        io: StringIO.new(xml_body),
        filename: "#{invoice.public_id}.xml",
        content_type: "application/xml",
        identify: false
      ) unless invoice.xml_file.attached?

      invoice.pdf_file.attach(
        io: StringIO.new(pdf_body),
        filename: "#{invoice.public_id}.pdf",
        content_type: "application/pdf",
        identify: false
      ) unless invoice.pdf_file.attached?

      { xml_sha256: xml_sha256, pdf_sha256: pdf_sha256 }
    end

    def self.verify_checksum!(actual_sha256, expected_sha256, label)
      return if expected_sha256.blank?
      return if ActiveSupport::SecurityUtils.secure_compare(actual_sha256, expected_sha256)

      raise InvalidTransition, "#{label} evidence checksum does not match provider payload."
    end

    def self.xml_payload(invoice, result)
      <<~XML
        <nfse>
          <numero>#{ERB::Util.html_escape(result.provider_invoice_number)}</numero>
          <codigo_verificacao>#{ERB::Util.html_escape(result.provider_verification_code)}</codigo_verificacao>
          <protocolo>#{ERB::Util.html_escape(result.provider_protocol)}</protocolo>
          <public_id>#{ERB::Util.html_escape(invoice.public_id)}</public_id>
        </nfse>
      XML
    end

    def self.pdf_payload(invoice, result)
      "FiscalBridge NFS-e #{invoice.public_id} #{result.provider_invoice_number}\n"
    end
  end
end
