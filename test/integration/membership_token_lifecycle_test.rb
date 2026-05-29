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
end
