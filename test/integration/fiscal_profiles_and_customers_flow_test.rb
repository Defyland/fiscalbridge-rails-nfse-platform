require "test_helper"

class FiscalProfilesAndCustomersFlowTest < ActionDispatch::IntegrationTest
  test "creates and lists fiscal profiles and customers" do
    bootstrap = bootstrap_organization(slug: unique_slug("profiles"))
    token = bootstrap.dig("owner", "api_token")

    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)

    get "/v1/fiscal_profiles", headers: auth_headers(token)

    assert_response :success
    assert_equal profile.fetch("id"), json_response.fetch("fiscal_profiles").first.fetch("id")

    get "/v1/customers", headers: auth_headers(token)

    assert_response :success
    assert_equal customer.fetch("id"), json_response.fetch("customers").first.fetch("id")
  end
end
