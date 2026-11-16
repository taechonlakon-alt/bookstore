require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionController::Base.cache_store.clear }
  teardown { ActionController::Base.cache_store.clear }

  test "reset instructions are emailed to an existing user" do
    assert_emails 1 do
      post user_password_path, params: { user: { email: users(:regular).email } }
    end
    assert_redirected_to new_user_session_path
  end

  test "password reset is rate limited" do
    10.times do
      post user_password_path, params: { user: { email: "missing@example.com" } }
      assert_response :unprocessable_content
    end

    post user_password_path, params: { user: { email: users(:regular).email } }
    assert_redirected_to new_user_password_path
    assert_equal "Try again later.", flash[:alert]
  end
end
