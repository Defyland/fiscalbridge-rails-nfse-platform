require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "normalizes slug and tax id" do
    organization = Organization.create!(
      name: "Acme Fiscal",
      slug: "Acme Fiscal Unit",
      legal_name: "Acme Fiscal Ltda",
      tax_id: "11.222.333/0001-81"
    )

    assert_equal "acme-fiscal-unit", organization.slug
    assert_equal "11222333000181", organization.tax_id
  end

  test "tracks seat and invoice quotas" do
    organization = Organization.create!(
      name: "Quota Tenant",
      slug: unique_slug("quota"),
      seat_limit: 1,
      monthly_invoice_limit: 1
    )

    assert organization.seat_available?
    assert organization.invoice_quota_available?

    organization.update!(current_month_invoice_count: 1)

    assert_not organization.invoice_quota_available?
  end
end
