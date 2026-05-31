require "application_system_test_case"

class BackofficeAuthenticationTest < ApplicationSystemTestCase
  test "user signs in and reaches the operational dashboard" do
    sign_in_as users(:owner_user)

    assert_text "Operacao fiscal"
    assert_text organizations(:acme).slug
    assert_text "Notas recentes"
  end

  test "invalid credentials keep the user on sign in" do
    visit new_session_path
    fill_in "Email", with: users(:owner_user).email_address
    fill_in "Senha", with: "wrong-password"
    click_on "Entrar"

    assert_text "Credenciais invalidas"
    assert_no_text "Operacao fiscal"
  end

  test "expired browser sessions are rejected" do
    sign_in_as users(:owner_user)
    Session.order(:created_at).last.update!(expires_at: 1.minute.ago)

    visit dashboard_path

    assert_current_path new_session_path
    assert_text "Backoffice operacional de NFS-e"
  end

  test "browser sessions are rejected when the user agent changes" do
    sign_in_as users(:owner_user)
    Session.order(:created_at).last.update!(user_agent: "Different browser")

    visit dashboard_path

    assert_current_path new_session_path
    assert_text "Backoffice operacional de NFS-e"
  end

  test "login attempts are rate limited" do
    previous_limit = ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"]
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = "2"

    3.times do
      visit new_session_path
      fill_in "Email", with: users(:owner_user).email_address
      fill_in "Senha", with: "wrong-password"
      click_on "Entrar"
    end

    assert_text "Muitas tentativas"
  ensure
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = previous_limit
  end
end
