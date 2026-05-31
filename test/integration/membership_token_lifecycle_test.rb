require "test_helper"

class MembershipTokenLifecycleTest < ActionDispatch::IntegrationTest
  test "owner creates rotates and revokes an operator token" do
    bootstrap = bootstrap_organization(slug: unique_slug("membership"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "operator@tenant.test",
        full_name: "Operator User",
        role: "operator"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    membership_id = json_response.dig("membership", "id")
    original_token = json_response.dig("membership", "api_token")
    assert_match(/\Afb_member_/, original_token)

    patch "/v1/memberships/#{membership_id}/rotate_token", headers: auth_headers(owner_token), as: :json

    assert_response :success
    rotated_token = json_response.dig("membership", "api_token")
    assert_not_equal original_token, rotated_token

    patch "/v1/memberships/#{membership_id}/revoke_token", headers: auth_headers(owner_token), as: :json

    assert_response :success

    get "/v1/organization", headers: auth_headers(rotated_token)

    assert_response :unauthorized
  end

  test "auditor cannot rotate membership tokens" do
    bootstrap = bootstrap_organization(slug: unique_slug("auditor-token"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "auditor@tenant.test",
        full_name: "Auditor User",
        role: "auditor"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    auditor_id = json_response.dig("membership", "id")
    auditor_token = json_response.dig("membership", "api_token")

    patch "/v1/memberships/#{auditor_id}/rotate_token", headers: auth_headers(auditor_token), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
  end

  test "lists memberships through bounded numeric cursor pagination" do
    bootstrap = bootstrap_organization(slug: unique_slug("membership-pagination"))
    owner_token = bootstrap.dig("owner", "api_token")

    3.times do |index|
      post "/v1/memberships", params: {
        membership: {
          email: "operator-#{index}@tenant.test",
          full_name: "Operator #{index}",
          role: "operator"
        }
      }, headers: auth_headers(owner_token), as: :json

      assert_response :created
    end

    get "/v1/memberships", params: { limit: 2 }, headers: auth_headers(owner_token)

    assert_response :success
    first_page = json_response
    assert_equal 2, first_page.fetch("memberships").size
    assert first_page.dig("pagination", "next_cursor").present?

    get "/v1/memberships",
        params: { limit: 2, cursor: first_page.dig("pagination", "next_cursor") },
        headers: auth_headers(owner_token)

    assert_response :success
    assert_equal 2, json_response.fetch("memberships").size
    assert_nil json_response.dig("pagination", "next_cursor")
  end
end
