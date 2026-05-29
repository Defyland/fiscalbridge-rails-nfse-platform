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
end
