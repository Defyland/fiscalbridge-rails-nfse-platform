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

  test "skips an event that is already being processed and is not stale" do
    organization = Organization.create!(name: "Processing Tenant", slug: unique_slug("processing"))
    event = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "processing",
      idempotency_key: "processing-key",
      status: "processing",
      processing_started_at: 1.minute.ago,
      attempts_count: 1
    )

    with_stubbed_singleton(OutboundEventDispatchJob, :deliver, ->(_event) { flunk "delivery should not run" }) do
      OutboundEventDispatchJob.perform_now(event.id)
    end

    event.reload
    assert_equal "processing", event.status
    assert_equal 1, event.attempts_count
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

  test "dispatches stale processing events through the sweeper job" do
    organization = Organization.create!(name: "Stale Sweeper Tenant", slug: unique_slug("stale-sweeper"))
    stale = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "stale",
      idempotency_key: "stale-sweeper",
      status: "processing",
      processing_started_at: OutboundEvent::PROCESSING_TIMEOUT.ago - 1.second,
      attempts_count: 1
    )
    active = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 2,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000002" },
      correlation_id: "active",
      idempotency_key: "active-processing",
      status: "processing",
      processing_started_at: 1.minute.ago,
      attempts_count: 1
    )
    OutboundEvent.where.not(id: [ stale.id, active.id ]).update_all(status: "dispatched")

    assert_enqueued_jobs 1, only: OutboundEventDispatchJob do
      DispatchDueOutboundEventsJob.perform_now
    end
    assert_enqueued_with(job: OutboundEventDispatchJob, args: [ stale.id ])
  end

  test "fails fast when outbound delivery adapter is unsupported" do
    previous_adapter = ENV["OUTBOUND_EVENT_DELIVERY_ADAPTER"]
    ENV["OUTBOUND_EVENT_DELIVERY_ADAPTER"] = "unsupported"
    organization = Organization.create!(name: "Adapter Tenant", slug: unique_slug("adapter"))
    event = organization.outbound_events.create!(
      aggregate_type: "ServiceInvoice",
      aggregate_id: 1,
      event_type: "service_invoice.created",
      payload: { invoice_id: "NFS-000001" },
      correlation_id: "adapter",
      idempotency_key: "adapter-key"
    )

    OutboundEventDispatchJob.perform_now(event.id)

    assert_equal "pending", event.reload.status
    assert_match "Unsupported outbound event delivery adapter", event.last_error
  ensure
    if previous_adapter.nil?
      ENV.delete("OUTBOUND_EVENT_DELIVERY_ADAPTER")
    else
      ENV["OUTBOUND_EVENT_DELIVERY_ADAPTER"] = previous_adapter
    end
  end
end
