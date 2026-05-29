require "test_helper"

class OrganizationsFlowTest < ActionDispatch::IntegrationTest
  test "bootstraps a fiscal tenant and returns owner token once" do
    slug = unique_slug("acme-fiscal")

    post "/v1/organizations", params: {
      organization: {
        name: "Acme Fiscal",
        slug: slug,
        legal_name: "Acme Fiscal Ltda",
        tax_id: "11.222.333/0001-81",
        municipal_registration: "123456",
        plan: "growth",
        monthly_invoice_limit: 750
      },
      owner: {
        email: "OWNER@ACME.TEST",
        full_name: "Owner Admin"
      }
    }, as: :json

    assert_response :created
    assert_equal slug, json_response.dig("organization", "slug")
    assert_equal "11222333000181", json_response.dig("organization", "tax_id")
    assert_match(/\Afb_owner_/, json_response.dig("owner", "api_token"))
    assert_equal "owner@acme.test", json_response.dig("owner", "email")
  end

  test "reads current organization with bearer token" do
    bootstrap = bootstrap_organization(slug: unique_slug("org-read"))
    token = bootstrap.dig("owner", "api_token")

    get "/v1/organization", headers: auth_headers(token)

    assert_response :success
    assert_equal bootstrap.dig("organization", "id"), json_response.dig("organization", "id")
    assert_equal "owner", json_response.dig("actor", "role")
  end
end
