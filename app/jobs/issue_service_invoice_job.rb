class IssueServiceInvoiceJob < ApplicationJob
  queue_as :default

  def perform(service_invoice_id)
    invoice = ServiceInvoice.find(service_invoice_id)
    return unless invoice.pending_issue?

    provider_request = invoice.provider_requests.issue.pending.recent_first.first
    return if provider_request.nil?

    result = Providers::SandboxNfseClient.issue(invoice)
    Invoices::ApplyIssueResult.call!(
      invoice: invoice,
      provider_request: provider_request,
      result: result
    )
  rescue Providers::SandboxNfseClient::TimeoutError => error
    mark_provider_timeout(service_invoice_id, error)
    raise
  end

  private

  def mark_provider_timeout(service_invoice_id, error)
    invoice = ServiceInvoice.find_by(id: service_invoice_id)
    return if invoice.nil?

    provider_request = invoice.provider_requests.issue.pending.recent_first.first
    provider_request&.update!(
      status: "failed",
      response_payload: { error: error.message },
      error_message: error.message,
      responded_at: Time.current
    )

    Auditing::Logger.log!(
      organization: invoice.organization,
      membership: nil,
      auditable: invoice,
      action: "service_invoice.provider_timeout",
      metadata: { error: error.message, provider_request_id: provider_request&.id }
    )

    Events::Publisher.publish!(
      organization: invoice.organization,
      aggregate: invoice,
      event_type: "service_invoice.provider_timeout",
      payload: { service_invoice: invoice.as_api_json, error: error.message }
    )
  end
end
