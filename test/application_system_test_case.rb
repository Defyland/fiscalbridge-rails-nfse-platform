require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["SYSTEM_TEST_DRIVER"] == "selenium"
    require "selenium/webdriver"

    Capybara.register_driver :fiscalbridge_headless_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless=new")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--no-sandbox")
      options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?

      driver_options = { browser: :chrome, options: options }
      if ENV["CHROMEDRIVER_PATH"].present?
        driver_options[:service] = Selenium::WebDriver::Service.chrome(path: ENV["CHROMEDRIVER_PATH"])
      end

      Capybara::Selenium::Driver.new(app, **driver_options)
    end

    driven_by :fiscalbridge_headless_chrome, screen_size: [ 1400, 900 ]
  else
    driven_by :rack_test
  end

  private

  def sign_in_as(user, password: "password123")
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Senha", with: password
    click_on "Entrar"

    assert_text "Operacao fiscal"
  end
end
