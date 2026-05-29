require "test_helper"

class InvoiceSequenceTest < ActiveSupport::TestCase
  test "allocates deterministic tenant invoice identifiers" do
    organization = Organization.create!(name: "Sequence Tenant", slug: unique_slug("sequence"), monthly_invoice_limit: 2)
    actor = create_membership(organization: organization, role: "owner")
    profile = create_profile(organization: organization)
    customer = create_customer_record(organization: organization)

    first = Invoices::Create.call!(
      organization: organization,
      actor: actor,
      idempotency_key: "sequence-1",
      attributes: invoice_attributes(profile, customer)
    ).invoice
    second = Invoices::Create.call!(
      organization: organization,
      actor: actor,
      idempotency_key: "sequence-2",
      attributes: invoice_attributes(profile, customer)
    ).invoice

    assert_equal "NFS-000001", first.public_id
    assert_equal "NFS-000002", second.public_id
  end

  test "replays invoice creation by idempotency key" do
    organization = Organization.create!(name: "Idempotency Tenant", slug: unique_slug("idempotency"))
    actor = create_membership(organization: organization, role: "owner")
    profile = create_profile(organization: organization)
    customer = create_customer_record(organization: organization)

    first = Invoices::Create.call!(
      organization: organization,
      actor: actor,
      idempotency_key: "same-key",
      attributes: invoice_attributes(profile, customer)
    )
    second = Invoices::Create.call!(
      organization: organization,
      actor: actor,
      idempotency_key: "same-key",
      attributes: invoice_attributes(profile, customer).merge(amount_cents: 999_00)
    )

    assert_equal first.invoice, second.invoice
    assert second.idempotent_replay
    assert_equal 1, organization.service_invoices.count
  end

  private

  def invoice_attributes(profile, customer)
    {
      fiscal_profile: profile,
      customer: customer,
      service_description: "Implementation",
      service_code: "6201501",
      amount_cents: 100_00,
      tax_rate_bps: 200
    }
  end
end
