require "test_helper"
require "digest"

class ProviderAdapterContractTest < ActiveSupport::TestCase
  test "sandbox provider implements the fiscal provider port" do
    invoice = create_invoice_record(status: "issued")
    invoice.update!(
      provider_invoice_number: "NFSE-#{invoice.public_id}",
      provider_verification_code: "VERIFY123",
      provider_protocol: "PROTO-123",
      xml_url: "https://storage.local/#{invoice.public_id}.xml",
      pdf_url: "https://storage.local/#{invoice.public_id}.pdf",
      issued_at: Time.current
    )

    provider = Providers::SandboxNfseClient
    %i[issue cancel fetch_status download_xml download_pdf].each do |method_name|
      assert_respond_to provider, method_name
    end

    status = provider.fetch_status(invoice, environment: "sandbox")
    assert_equal provider.provider_name, status.provider_name
    assert_equal "fetch_status", status.operation
    assert_equal "sandbox", status.environment
    assert_equal invoice.status, status.status

    xml = provider.download_xml(invoice, environment: "sandbox")
    assert_equal "xml", xml.document_type
    assert_equal "application/xml", xml.content_type
    assert_equal Digest::SHA256.hexdigest(xml.body), xml.sha256
    assert_equal invoice.xml_url, xml.source_url

    pdf = provider.download_pdf(invoice, environment: "sandbox")
    assert_equal "pdf", pdf.document_type
    assert_equal "application/pdf", pdf.content_type
    assert_equal Digest::SHA256.hexdigest(pdf.body), pdf.sha256
    assert_equal invoice.pdf_url, pdf.source_url
  end

  test "sandbox provider returns normalized idempotency metadata" do
    invoice = create_invoice_record
    provider = Providers::SandboxNfseClient

    issue = provider.issue(invoice, idempotency_key: "issue-key", environment: "sandbox")
    assert_equal provider.provider_name, issue.provider_name
    assert_equal "issue", issue.operation
    assert_equal "sandbox", issue.environment
    assert_equal "issue-key", issue.raw_metadata.fetch(:idempotency_key)

    cancel = provider.cancel(
      invoice,
      idempotency_key: "cancel-key",
      reason: "Customer request",
      environment: "sandbox"
    )
    assert_equal provider.provider_name, cancel.provider_name
    assert_equal "cancel", cancel.operation
    assert_equal "sandbox", cancel.environment
    assert_equal "cancel-key", cancel.raw_metadata.fetch(:idempotency_key)
  end
end
