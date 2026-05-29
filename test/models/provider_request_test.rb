require "test_helper"

class ProviderRequestTest < ActiveSupport::TestCase
  test "requires globally unique idempotency key" do
    invoice = create_invoice_record

    ProviderRequest.create!(
      organization: invoice.organization,
      service_invoice: invoice,
      provider_name: "sandbox_nfse",
      action: "issue",
      status: "pending",
      idempotency_key: "provider-key",
      correlation_id: "correlation"
    )

    duplicate = ProviderRequest.new(
      organization: invoice.organization,
      service_invoice: invoice,
      provider_name: "sandbox_nfse",
      action: "issue",
      status: "pending",
      idempotency_key: "provider-key",
      correlation_id: "other"
    )

    assert_not duplicate.valid?
  end
end
