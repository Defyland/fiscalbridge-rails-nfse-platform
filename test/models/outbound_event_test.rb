require "test_helper"

class OutboundEventTest < ActiveSupport::TestCase
  test "orders due events by creation time" do
    organization = Organization.create!(name: "Events Tenant", slug: unique_slug("events"))
    late = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 2,
      event_type: "service_invoice.issued",
      payload: { invoice_id: "NFS-000002" },
      correlation_id: "late",
      idempotency_key: "late",
      next_attempt_at: 5.minutes.from_now
    )
    due = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "due",
      idempotency_key: "due",
      next_attempt_at: 1.minute.ago
    )

    assert_includes OutboundEvent.due_for_dispatch, due
    assert_not_includes OutboundEvent.due_for_dispatch, late
  end
end
