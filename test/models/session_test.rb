require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "new sessions receive explicit expiry and last seen timestamps" do
    session = users(:owner_user).sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    assert session.expires_at.future?
    assert session.last_seen_at.present?
    assert_not session.expired?
  end

  test "expired sessions are identifiable" do
    assert sessions(:expired_owner_session).expired?
    assert_not sessions(:owner_session).expired?
  end
end
