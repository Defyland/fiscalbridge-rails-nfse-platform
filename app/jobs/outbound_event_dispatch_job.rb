class OutboundEventDispatchJob < ApplicationJob
  class UnsupportedEventType < StandardError; end

  queue_as :default
  MAX_ATTEMPTS = 5
  BASE_RETRY_DELAY = 30.seconds

  SUPPORTED_EVENT_TYPES = %w[
    organization.bootstrapped
    membership.created
    membership.updated
    membership.token_revoked
    membership.token_rotated
    fiscal_profile.created
    fiscal_profile.updated
    customer.created
    customer.updated
    service_invoice.created
    service_invoice.issue_requested
    service_invoice.issued
    service_invoice.rejected
    service_invoice.cancel_requested
    service_invoice.cancelled
    service_invoice.cancellation_failed
    service_invoice.status_polled
    service_invoice.provider_timeout
  ].freeze

  def perform(outbound_event_id)
    event = claim_event(outbound_event_id)
    return if event.nil?

    raise UnsupportedEventType, "Unsupported event type #{event.event_type}" unless SUPPORTED_EVENT_TYPES.include?(event.event_type)

    self.class.deliver(event)

    mark_dispatched(event.id)

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: "dispatched"
    )

    Rails.logger.info(
      message: "outbound_event_dispatched",
      event_id: event.id,
      event_type: event.event_type,
      organization_id: event.organization_id
    )
  rescue UnsupportedEventType => error
    mark_unsupported_event(outbound_event_id, error)
    raise
  rescue StandardError => error
    schedule_retry_or_failure(outbound_event_id, error)
  end

  def self.deliver(event)
    Events::Delivery.deliver!(event)
  end

  private

  def claim_event(outbound_event_id)
    OutboundEvent.transaction do
      event = OutboundEvent.lock.find_by(id: outbound_event_id)

      if event.nil? || event.dispatched?
        nil
      elsif event.processing? && !processing_stale?(event)
        nil
      elsif event.pending? && event.next_attempt_at.present? && event.next_attempt_at.future?
        nil
      else
        event.update!(
          status: "processing",
          processing_started_at: Time.current,
          attempts_count: event.attempts_count + 1,
          last_error: nil,
          next_attempt_at: nil
        )
        event
      end
    end
  end

  def processing_stale?(event)
    event.processing_started_at.nil? || event.processing_started_at <= OutboundEvent::PROCESSING_TIMEOUT.ago
  end

  def mark_dispatched(outbound_event_id)
    event = OutboundEvent.find_by(id: outbound_event_id)
    return if event.nil?

    event.update!(
      status: "dispatched",
      dispatched_at: Time.current,
      processing_started_at: nil,
      last_error: nil,
      next_attempt_at: nil
    )
  end

  def mark_unsupported_event(outbound_event_id, error)
    event = OutboundEvent.find_by(id: outbound_event_id)
    return if event.nil?

    event.update_columns(
      status: "failed",
      attempts_count: [ event.attempts_count, 1 ].max,
      last_error: error.message,
      processing_started_at: nil,
      next_attempt_at: nil,
      updated_at: Time.current
    )

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: event.status
    )
  end

  def schedule_retry_or_failure(outbound_event_id, error)
    event = OutboundEvent.find_by(id: outbound_event_id)
    return if event.nil?

    next_attempt_at = nil
    final_failure = nil

    event.with_lock do
      attempts_count = [ event.attempts_count, 1 ].max
      final_failure = attempts_count >= MAX_ATTEMPTS

      next_attempt_at = final_failure ? nil : retry_at(attempts_count)

      event.update_columns(
        status: final_failure ? "failed" : "pending",
        attempts_count: attempts_count,
        last_error: error.message,
        processing_started_at: nil,
        next_attempt_at: next_attempt_at,
        updated_at: Time.current
      )
    end

    self.class.set(wait_until: next_attempt_at).perform_later(event.id) unless final_failure

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: event.status
    )
  end

  def retry_at(attempts_count)
    Time.current + (BASE_RETRY_DELAY * (2**(attempts_count - 1)))
  end
end
