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
  ensure
    Current.reset
  end
end
