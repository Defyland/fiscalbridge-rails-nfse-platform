require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "authenticates active non-expired tokens by digest" do
    organization = Organization.create!(name: "Token Tenant", slug: unique_slug("token"))
    token, digest = Tokens::Issuer.issue
    membership = organization.memberships.create!(
      email: "operator@tenant.test",
      full_name: "Operator User",
      role: "operator",
      api_token_digest: digest,
      api_token_last_eight: token.last(8),
      api_token_expires_at: 1.day.from_now
    )

    assert_equal membership, Membership.authenticate(token)
  end

  test "rejects revoked tokens" do
    organization = Organization.create!(name: "Revoked Tenant", slug: unique_slug("revoked"))
    token, digest = Tokens::Issuer.issue
    membership = organization.memberships.create!(
      email: "operator@tenant.test",
      full_name: "Operator User",
      role: "operator",
      api_token_digest: digest,
      api_token_last_eight: token.last(8),
      api_token_expires_at: 1.day.from_now
    )
    membership.update!(api_token_revoked_at: 1.second.from_now)

    assert_nil Membership.authenticate(token)
  end
end
