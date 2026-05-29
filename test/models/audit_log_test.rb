require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  test "allows provider-originated audit entries without membership" do
    invoice = create_invoice_record

    audit_log = AuditLog.create!(
      organization: invoice.organization,
      membership: nil,
      auditable: invoice,
      action: "service_invoice.provider_callback",
      metadata: { provider_status: "issued" }
    )

    assert audit_log.persisted?
  end
end
