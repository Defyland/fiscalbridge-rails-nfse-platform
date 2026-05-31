require "test_helper"

class EventsPublisherContractTest < ActiveSupport::TestCase
  FISCAL_ENVELOPE_FIELDS = %w[
    event_id
    event_type
    schema_version
    occurred_at
    producer
    organization_id
    service_invoice_id
    correlation_id
    provider
    environment
    payload
  ].freeze

  test "persists fiscal outbox events with the documented external envelope" do
    invoice = create_invoice_record(status: "issued")
    invoice.update!(
      provider_invoice_number: "NFSE-#{invoice.public_id}",
      provider_verification_code: "VERIFY123",
      provider_protocol: "PROTO-123",
      xml_sha256: "a" * 64,
      pdf_sha256: "b" * 64,
      issued_at: Time.current
    )
    Current.correlation_id = "contract-correlation"

    event = Events::Publisher.publish!(
      organization: invoice.organization,
      aggregate: invoice,
      event_type: "service_invoice.issued",
      payload: {
        service_invoice: invoice.as_api_json,
        provider_request_id: 123
      }
    )

    envelope = event.reload.payload

    FISCAL_ENVELOPE_FIELDS.each { |field| assert envelope.key?(field), "missing #{field}" }
    assert_match(/\Aevt_/, envelope.fetch("event_id"))
    assert_equal "service_invoice.issued", envelope.fetch("event_type")
    assert_equal 1, envelope.fetch("schema_version")
    assert_equal "fiscalbridge", envelope.fetch("producer")
    assert_equal invoice.organization.slug, envelope.fetch("organization_id")
    assert_equal invoice.public_id, envelope.fetch("service_invoice_id")
    assert_equal "contract-correlation", envelope.fetch("correlation_id")
    assert_equal "sandbox_nfse", envelope.fetch("provider")
    assert_equal invoice.fiscal_profile.environment, envelope.fetch("environment")
    assert_equal invoice.public_id, envelope.dig("payload", "service_invoice", "id")
    assert_equal 123, envelope.dig("payload", "provider_request_id")
    assert_equal invoice.provider_invoice_number, envelope.dig("payload", "provider_invoice_number")
    assert_equal invoice.provider_protocol, envelope.dig("payload", "provider_protocol")
    assert_equal "a" * 64, envelope.dig("payload", "xml_sha256")
    assert_equal "b" * 64, envelope.dig("payload", "pdf_sha256")
    assert_required_schema_payload_fields("service_invoice_issued.v1.json", envelope.fetch("payload"))
  ensure
    Current.reset
  end

  test "created fiscal event payload satisfies the documented required fields" do
    invoice = create_invoice_record

    event = Events::Publisher.publish!(
      organization: invoice.organization,
      aggregate: invoice,
      event_type: "service_invoice.created",
      payload: {
        service_invoice: invoice.as_api_json,
        actor_membership_id: invoice.created_by_membership_id
      }
    )

    assert_required_schema_payload_fields("service_invoice_created.v1.json", event.reload.payload.fetch("payload"))
  end

  private

  def assert_required_schema_payload_fields(schema_name, payload)
    schema = JSON.parse(File.read(Rails.root.join("docs/events", schema_name)))
    required_fields = schema.dig("properties", "payload", "required")

    required_fields.each do |field|
      assert payload.key?(field), "#{schema_name} requires payload.#{field}"
      assert_not_nil payload.fetch(field), "#{schema_name} requires payload.#{field} to be present"
    end
  end
end
