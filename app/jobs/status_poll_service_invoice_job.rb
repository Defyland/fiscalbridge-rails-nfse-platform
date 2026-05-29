class StatusPollServiceInvoiceJob < ApplicationJob
  queue_as :default

  def perform(service_invoice_id, provider_request_id)
    invoice = ServiceInvoice.find(service_invoice_id)
    provider_request = ProviderRequest.find(provider_request_id)
    result = Providers::SandboxNfseClient.status(invoice)

    provider_request.update!(
      status: "succeeded",
      response_payload: result.to_h,
      responded_at: Time.current
    )

    Events::Publisher.publish!(
      organization: invoice.organization,
      aggregate: invoice,
      event_type: "service_invoice.status_polled",
      payload: { service_invoice: invoice.as_api_json, provider_request_id: provider_request.id }
    )
  end
end
