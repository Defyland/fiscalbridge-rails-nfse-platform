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
        payload: fiscal_payload(aggregate, payload)
      }
    end

    def self.fiscal_payload(aggregate, payload)
      raw_payload = payload.deep_stringify_keys
      service_invoice = raw_payload["service_invoice"] || aggregate.as_api_json.deep_stringify_keys

      stable_payload = {
        "service_invoice" => service_invoice,
        "status" => aggregate.status,
        "amount_cents" => aggregate.amount_cents,
        "customer_document" => aggregate.customer.document_number,
        "fiscal_profile_id" => aggregate.fiscal_profile_id,
        "idempotency_key" => aggregate.idempotency_key,
        "lock_version" => aggregate.lock_version,
        "provider_invoice_number" => aggregate.provider_invoice_number,
        "provider_verification_code" => aggregate.provider_verification_code,
        "provider_protocol" => aggregate.provider_protocol,
        "rejection_reason" => aggregate.rejection_reason,
        "cancellation_reason" => aggregate.cancellation_reason,
        "issued_at" => aggregate.issued_at&.iso8601,
        "cancelled_at" => aggregate.cancelled_at&.iso8601,
        "xml_sha256" => aggregate.xml_sha256,
        "pdf_sha256" => aggregate.pdf_sha256
      }.compact

      stable_payload.merge(raw_payload.except("service_invoice"))
    end

    def self.fiscal_event?(aggregate, event_type)
      event_type.to_s.start_with?("service_invoice.") && aggregate.respond_to?(:public_id)
    end

    def self.provider_for(aggregate)
      aggregate.provider_requests.recent_first.first&.provider_name || Providers::SandboxNfseClient.provider_name
    end

    private_class_method :normalize_payload, :fiscal_payload, :fiscal_event?, :provider_for
  end
end
