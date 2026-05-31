require "test_helper"

class MutationTransactionBoundariesTest < ActiveSupport::TestCase
  test "membership update rolls back when event publication fails" do
    organization = Organization.create!(name: "Rollback Tenant", slug: unique_slug("rollback"))
    actor = create_membership(organization: organization, role: "owner")
    membership = create_membership(organization: organization, email: "operator@tenant.test", role: "operator")

    with_stubbed_singleton(Events::Publisher, :publish!, ->(**_args) { raise "outbox unavailable" }) do
      assert_raises(RuntimeError) do
        Memberships::Update.call!(
          membership: membership,
          actor: actor,
          attributes: { role: "admin" }
        )
      end
    end

    assert_equal "operator", membership.reload.role
    assert_not AuditLog.exists?(action: "membership.updated")
  end

  test "invoice issue rolls back provider request when event publication fails" do
    invoice = create_invoice_record
    actor = invoice.created_by_membership

    with_stubbed_singleton(Events::Publisher, :publish!, ->(**_args) { raise "outbox unavailable" }) do
      assert_raises(RuntimeError) do
        Invoices::Issue.call!(
          invoice: invoice,
          actor: actor,
          expected_lock_version: invoice.lock_version
        )
      end
    end

    assert_equal "draft", invoice.reload.status
    assert_equal 0, invoice.provider_requests.count
    assert_not AuditLog.exists?(action: "service_invoice.issue_requested")
  end

  test "customer creation rolls back when event publication fails" do
    organization = Organization.create!(name: "Customer Rollback Tenant", slug: unique_slug("customer-rollback"))
    actor = create_membership(organization: organization, role: "owner")

    with_stubbed_singleton(Events::Publisher, :publish!, ->(**_args) { raise "outbox unavailable" }) do
      assert_raises(RuntimeError) do
        Customers::Create.call!(
          organization: organization,
          actor: actor,
          attributes: {
            legal_name: "Rollback Buyer Ltda",
            document_type: "cnpj",
            document_number: "33111222000144",
            city_code: "3550308"
          }
        )
      end
    end

    assert_equal 0, organization.customers.count
    assert_not AuditLog.exists?(action: "customer.created")
  end

  test "fiscal profile update rolls back when event publication fails" do
    organization = Organization.create!(name: "Profile Rollback Tenant", slug: unique_slug("profile-rollback"))
    actor = create_membership(organization: organization, role: "owner")
    profile = create_profile(organization: organization)

    with_stubbed_singleton(Events::Publisher, :publish!, ->(**_args) { raise "outbox unavailable" }) do
      assert_raises(RuntimeError) do
        FiscalProfiles::Update.call!(
          profile: profile,
          actor: actor,
          attributes: { trade_name: "Should Roll Back" }
        )
      end
    end

    assert_nil profile.reload.trade_name
    assert_not AuditLog.exists?(action: "fiscal_profile.updated")
  end
end
