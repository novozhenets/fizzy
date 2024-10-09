require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  ALLOWED_BROWSER    = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
  DISALLOWED_BROWSER = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/114.0"

  test "new" do
    get new_session_url
    assert_response :success
  end

  test "new enforces browser compatibility" do
    get new_session_url, env: { "HTTP_USER_AGENT" => DISALLOWED_BROWSER }
    assert_select "svg", message: /Your browser is not supported/

    get new_session_url, env: { "HTTP_USER_AGENT" => ALLOWED_BROWSER }
    assert_select "svg", text: /Your browser is not supported/, count: 0
  end

  test "create with valid credentials" do
    post session_url, params: { email_address: "david@37signals.com", password: "secret123456" }
    assert_redirected_to root_url
    assert cookies[:session_token].present?
  end

  test "create with invalid credentials" do
    post session_url, params: { email_address: "david@37signals.com", password: "wrong" }
    assert_redirected_to new_session_url
    assert_not cookies[:session_token].present?
  end

  test "destroy" do
    sign_in_as :kevin
    delete session_url
    assert_redirected_to new_session_url
    assert_not cookies[:session_token].present?
  end
end
