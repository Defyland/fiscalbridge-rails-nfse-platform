require "test_helper"

class AuthorizationAndIsolationTest < ActionDispatch::IntegrationTest
  test "auditor cannot create service invoices" do
    bootstrap = bootstrap_organization(slug: unique_slug("auditor"))
    owner_token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: owner_token)
    customer = create_customer(token: owner_token)

    post "/v1/memberships", params: {
      membership: {
        email: "auditor@tenant.test",
        full_name: "Auditor User",
        role: "auditor"
      }
    }, headers: auth_headers(owner_token), as: :json

    auditor_token = json_response.dig("membership", "api_token")

    post "/v1/service_invoices", params: {
      service_invoice: {
        fiscal_profile_id: profile.fetch("id"),
        customer_id: customer.fetch("id"),
        service_description: "Unauthorized services",
        service_code: "6201501",
        amount_cents: 100_00
      }
    }, headers: auth_headers(auditor_token, "Idempotency-Key" => "auditor-create"), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
  end

  test "tenant tokens cannot read another tenant invoice" do
    first = bootstrap_organization(slug: unique_slug("tenant-a"))
    first_token = first.dig("owner", "api_token")
    profile = create_fiscal_profile(token: first_token)
    customer = create_customer(token: first_token)
    create_service_invoice(token: first_token, fiscal_profile_id: profile.fetch("id"), customer_id: customer.fetch("id"))

    second = bootstrap_organization(slug: unique_slug("tenant-b"))
    second_token = second.dig("owner", "api_token")

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(second_token)

    assert_response :not_found
    assert_equal "not_found", json_response.dig("error", "code")
  end
end
