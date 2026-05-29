require "test_helper"

class ServiceInvoiceTest < ActiveSupport::TestCase
  test "validates tenant-owned associations" do
    first = Organization.create!(name: "First Tenant", slug: unique_slug("first"))
    second = Organization.create!(name: "Second Tenant", slug: unique_slug("second"))
    actor = create_membership(organization: first)
    profile = create_profile(organization: first)
    customer = create_customer_record(organization: second)

    invoice = first.service_invoices.new(
      fiscal_profile: profile,
      customer: customer,
      created_by_membership: actor,
      public_id: "NFS-000001",
      idempotency_key: "tenant-check",
      service_description: "Implementation",
      service_code: "6201501",
      amount_cents: 100_00
    )

    assert_not invoice.valid?
    assert_includes invoice.errors[:customer], "must belong to the same organization"
  end

  test "exposes issue and cancel capabilities by status" do
    invoice = build_invoice

    assert invoice.can_issue?
    assert_not invoice.can_cancel?

    invoice.status = "issued"

    assert_not invoice.can_issue?
    assert invoice.can_cancel?
  end

  private

  def build_invoice
    organization = Organization.create!(name: "Invoice Tenant", slug: unique_slug("invoice"))
    organization.service_invoices.new(
      fiscal_profile: create_profile(organization: organization),
      customer: create_customer_record(organization: organization),
      created_by_membership: create_membership(organization: organization),
      public_id: "NFS-000001",
      idempotency_key: "invoice-key",
      service_description: "Implementation",
      service_code: "6201501",
      amount_cents: 100_00
    )
  end
end
