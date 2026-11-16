require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionController::Base.cache_store.clear }
  teardown { ActionController::Base.cache_store.clear }

  test "sign in is rate limited" do
    10.times do
      post user_session_path, params: { user: { email: "admin@example.com", password: "nope" } }
      assert_response :unprocessable_content
    end

    post user_session_path, params: { user: { email: "admin@example.com", password: "password" } }
    assert_redirected_to new_user_session_path
    assert_equal "Try again later.", flash[:alert]
  end
end
