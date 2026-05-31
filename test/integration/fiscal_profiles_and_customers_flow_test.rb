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
    assert_equal 50, json_response.dig("pagination", "limit")

    get "/v1/customers", headers: auth_headers(token)

    assert_response :success
    assert_equal customer.fetch("id"), json_response.fetch("customers").first.fetch("id")
    assert_equal 50, json_response.dig("pagination", "limit")
  end

  test "lists fiscal profiles and customers through bounded numeric cursor pagination" do
    bootstrap = bootstrap_organization(slug: unique_slug("registry-pagination"))
    token = bootstrap.dig("owner", "api_token")

    3.times do |index|
      create_fiscal_profile(
        token: token,
        attributes: {
          legal_name: "Fiscal Profile #{index}",
          tax_id: "11#{index.to_s.rjust(12, '0')}",
          default_profile: index.zero?
        }
      )
      create_customer(
        token: token,
        attributes: {
          legal_name: "Customer #{index}",
          document_number: "22#{index.to_s.rjust(12, '0')}"
        }
      )
    end

    get "/v1/fiscal_profiles", params: { limit: 2 }, headers: auth_headers(token)

    assert_response :success
    first_profile_page = json_response
    assert_equal 2, first_profile_page.fetch("fiscal_profiles").size
    assert first_profile_page.dig("pagination", "next_cursor").present?

    get "/v1/fiscal_profiles",
        params: { limit: 2, cursor: first_profile_page.dig("pagination", "next_cursor") },
        headers: auth_headers(token)

    assert_response :success
    assert_equal 1, json_response.fetch("fiscal_profiles").size
    assert_nil json_response.dig("pagination", "next_cursor")

    get "/v1/customers", params: { limit: 2 }, headers: auth_headers(token)

    assert_response :success
    first_customer_page = json_response
    assert_equal 2, first_customer_page.fetch("customers").size
    assert first_customer_page.dig("pagination", "next_cursor").present?

    get "/v1/customers",
        params: { limit: 2, cursor: first_customer_page.dig("pagination", "next_cursor") },
        headers: auth_headers(token)

    assert_response :success
    assert_equal 1, json_response.fetch("customers").size
    assert_nil json_response.dig("pagination", "next_cursor")
  end

  test "rejects invalid numeric registry cursors" do
    bootstrap = bootstrap_organization(slug: unique_slug("invalid-registry-cursor"))
    token = bootstrap.dig("owner", "api_token")

    get "/v1/customers", params: { cursor: "not-a-number" }, headers: auth_headers(token)

    assert_response :bad_request
    assert_equal "invalid_cursor", json_response.dig("error", "code")
  end
end
