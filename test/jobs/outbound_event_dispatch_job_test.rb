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
      assert_enqueued_with(job: OutboundEventDispatchJob, args: [ event.id ]) do
        OutboundEventDispatchJob.perform_now(event.id)
      end
    end

    event.reload
    assert_equal "pending", event.status
    assert_equal 1, event.attempts_count
    assert_not_nil event.next_attempt_at
  end

  test "dispatches due pending events through the sweeper job" do
    organization = Organization.create!(name: "Sweeper Tenant", slug: unique_slug("sweeper"))
    due = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "due",
      idempotency_key: "due-sweeper",
      next_attempt_at: 1.minute.ago
    )
    future = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 2,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000002" },
      correlation_id: "future",
      idempotency_key: "future-sweeper",
      next_attempt_at: 5.minutes.from_now
    )
    OutboundEvent.where.not(id: [ due.id, future.id ]).update_all(status: "dispatched")

    assert_enqueued_jobs 1, only: OutboundEventDispatchJob do
      DispatchDueOutboundEventsJob.perform_now
    end
    assert_enqueued_with(job: OutboundEventDispatchJob, args: [ due.id ])
  end
end
