require "test_helper"

class MutedUiTest < ActionDispatch::IntegrationTest
  test "login, password and sign up pages use muted colors" do
    [ new_user_session_path, new_user_password_path, new_user_registration_path ].each do |path|
      get path
      assert_no_match(/blue-|shadow-/, response.body, "#{path} uses bright colors")
    end
  end
end
