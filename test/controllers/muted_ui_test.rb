require "test_helper"

class MutedUiTest < ActionDispatch::IntegrationTest
  test "login and password pages use muted colors" do
    [ new_session_path, new_password_path ].each do |path|
      get path
      assert_no_match(/blue-|shadow-/, response.body, "#{path} uses bright colors")
    end
  end
end
