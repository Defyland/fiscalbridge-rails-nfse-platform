require "test_helper"

class ServiceInvoiceJobsTest < ActiveJob::TestCase
  test "issue job applies provider success" do
    invoice = create_invoice_record
    invoice.update!(status: "pending_issue")
    request = invoice.provider_requests.create!(
      organization: invoice.organization,
      provider_name: "sandbox_nfse",
      action: "issue",
      status: "pending",
      idempotency_key: "issue-job",
      correlation_id: "correlation"
    )

    IssueServiceInvoiceJob.perform_now(invoice.id)

    assert_equal "issued", invoice.reload.status
    assert invoice.xml_file.attached?
    assert invoice.pdf_file.attached?
    assert_includes invoice.xml_file.download, invoice.customer.document_number
    assert_equal Digest::SHA256.hexdigest(invoice.xml_file.download), request.reload.response_payload.fetch("xml_sha256")
    assert_equal request.response_payload.fetch("xml_sha256"), invoice.xml_sha256
    assert_equal Digest::SHA256.hexdigest(invoice.pdf_file.download), invoice.pdf_sha256
    assert invoice.evidence_recorded_at.present?
    assert_equal "succeeded", request.reload.status
  end

  test "cancel job applies provider cancellation" do
    invoice = create_invoice_record(status: "issued")
    invoice.update!(status: "pending_cancellation", cancellation_reason: "Customer request")
    request = invoice.provider_requests.create!(
      organization: invoice.organization,
      provider_name: "sandbox_nfse",
      action: "cancel",
      status: "pending",
      idempotency_key: "cancel-job",
      correlation_id: "correlation"
    )

    CancelServiceInvoiceJob.perform_now(invoice.id)

    assert_equal "cancelled", invoice.reload.status
    assert_equal "succeeded", request.reload.status
  end
end
