require "test_helper"

class SecurityAuthorizerTest < ActiveSupport::TestCase
  test "owner can manage invoices and memberships" do
    owner = Membership.new(role: "owner")

    assert_nothing_raised do
      Security::Authorizer.authorize!(owner, :memberships_create)
      Security::Authorizer.authorize!(owner, :service_invoices_issue)
    end
  end

  test "auditor can read but cannot issue invoices" do
    auditor = Membership.new(role: "auditor")

    assert_nothing_raised { Security::Authorizer.authorize!(auditor, :service_invoices_read) }

    error = assert_raises(Security::AuthorizationError) do
      Security::Authorizer.authorize!(auditor, :service_invoices_issue)
    end

    assert_equal "auditor cannot perform service_invoices_issue.", error.message
  end
end
