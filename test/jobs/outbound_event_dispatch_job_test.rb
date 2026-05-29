require "test_helper"

class OutboundEventDispatchJobTest < ActiveJob::TestCase
  test "marks a supported outbound event as dispatched" do
    organization = Organization.create!(name: "Event Tenant", slug: unique_slug("event"))
    event = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "correlation",
      idempotency_key: "event-key"
    )

    OutboundEventDispatchJob.perform_now(event.id)

    assert_equal "dispatched", event.reload.status
    assert_not_nil event.dispatched_at
  end

  test "marks unsupported outbound event as failed" do
    organization = Organization.create!(name: "Unsupported Tenant", slug: unique_slug("unsupported"))
    event = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.unsupported",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "correlation",
      idempotency_key: "unsupported-key"
    )

    assert_raises(OutboundEventDispatchJob::UnsupportedEventType) do
      OutboundEventDispatchJob.perform_now(event.id)
    end

    assert_equal "failed", event.reload.status
    assert_match "Unsupported event type", event.last_error
  end

  test "schedules retry after delivery failure" do
    organization = Organization.create!(name: "Retry Tenant", slug: unique_slug("retry"))
    event = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "correlation",
      idempotency_key: "retry-key"
    )

    with_stubbed_singleton(OutboundEventDispatchJob, :deliver, ->(_event) { raise "network down" }) do
      assert_raises(RuntimeError) { OutboundEventDispatchJob.perform_now(event.id) }
    end

    event.reload
    assert_equal "pending", event.status
    assert_equal 1, event.attempts_count
    assert_not_nil event.next_attempt_at
  end
end
