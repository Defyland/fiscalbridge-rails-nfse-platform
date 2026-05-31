class CancelServiceInvoiceJob < ApplicationJob
  queue_as :default

  def perform(service_invoice_id)
    invoice = ServiceInvoice.find(service_invoice_id)
    return unless invoice.pending_cancellation?

    provider_request = invoice.provider_requests.cancel.pending.recent_first.first
    return if provider_request.nil?

    result = Providers::SandboxNfseClient.cancel(
      invoice,
      idempotency_key: provider_request.idempotency_key,
      reason: invoice.cancellation_reason,
      environment: invoice.fiscal_profile.environment
    )
    Invoices::ApplyCancellationResult.call!(
      invoice: invoice,
      provider_request: provider_request,
      result: result
    )
  end
end
