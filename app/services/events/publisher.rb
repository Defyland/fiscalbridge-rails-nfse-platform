module Events
  class Publisher
    def self.publish!(organization:, aggregate:, event_type:, payload:)
      correlation_id = Current.correlation_id || SecureRandom.uuid
      normalized_payload = normalize_payload(
        organization: organization,
        aggregate: aggregate,
        event_type: event_type,
        payload: payload,
        correlation_id: correlation_id
      )

      event = OutboundEvent.create!(
        organization: organization,
        aggregate_type: aggregate.class.name,
        aggregate_id: aggregate.id,
        event_type: event_type,
        payload: normalized_payload,
        correlation_id: correlation_id,
        idempotency_key: "#{event_type}:#{aggregate.class.name}:#{aggregate.id}:#{SecureRandom.uuid}"
      )

      ActiveRecord.after_all_transactions_commit do
        OutboundEventDispatchJob.perform_later(event.id)
      end

      event
    end

    def self.normalize_payload(organization:, aggregate:, event_type:, payload:, correlation_id:)
      return payload unless fiscal_event?(aggregate, event_type)

      {
        event_id: "evt_#{SecureRandom.uuid}",
        event_type: event_type,
        schema_version: 1,
        occurred_at: Time.current.iso8601,
        producer: "fiscalbridge",
        organization_id: organization.slug,
        service_invoice_id: aggregate.public_id,
        correlation_id: correlation_id,
        provider: provider_for(aggregate),
        environment: aggregate.fiscal_profile.environment,
        payload: payload
      }
    end

    def self.fiscal_event?(aggregate, event_type)
      event_type.to_s.start_with?("service_invoice.") && aggregate.respond_to?(:public_id)
    end

    def self.provider_for(aggregate)
      aggregate.provider_requests.recent_first.first&.provider_name || Providers::SandboxNfseClient.provider_name
    end

    private_class_method :normalize_payload, :fiscal_event?, :provider_for
  end
end
