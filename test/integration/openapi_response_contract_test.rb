require "test_helper"
require "yaml"

class OpenapiResponseContractTest < ActionDispatch::IntegrationTest
  test "service invoice responses expose documented contract keys" do
    bootstrap = bootstrap_organization(slug: unique_slug("contract"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)

    create_service_invoice(token: token, fiscal_profile_id: profile.fetch("id"), customer_id: customer.fetch("id"))

    service_invoice = json_response.fetch("service_invoice")
    assert_required_keys(service_invoice, %w[
      id
      status
      service_description
      service_code
      amount_cents
      tax_rate_bps
      lock_version
      fiscal_profile
      customer
      created_by
    ])
  end

  test "OpenAPI keeps versioned paths and shared error responses" do
    openapi = YAML.safe_load(File.read(Rails.root.join("openapi.yaml")), aliases: true)

    assert_equal "3.1.0", openapi.fetch("openapi")
    assert_includes openapi.fetch("paths").keys, "/v1/service_invoices"
    assert_includes openapi.fetch("paths").keys, "/v1/service_invoices/{id}/issue"
    assert_equal "bearer", openapi.dig("components", "securitySchemes", "BearerAuth", "scheme")
    assert openapi.dig("components", "responses").key?("ValidationFailed")
  end

  private

  def assert_required_keys(payload, keys)
    keys.each { |key| assert payload.key?(key), "expected #{key} in #{payload.inspect}" }
  end
end
