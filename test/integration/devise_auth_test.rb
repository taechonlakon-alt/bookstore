require "test_helper"

class DeviseAuthTest < ActionDispatch::IntegrationTest
  test "existing bcrypt user logs in with the old password" do
    post user_session_path, params: { user: { email: "ADMIN@example.com", password: "password" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "nav", /admin@example.com/
  end

  test "wrong password is rejected" do
    post user_session_path, params: { user: { email: "admin@example.com", password: "nope" } }
    assert_response :unprocessable_content
  end

  test "sign up creates a user with default role and logs them in" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: { user: { email: "New@Example.com", password: "secret123", password_confirmation: "secret123" } }
    end
    assert_equal "new@example.com", User.last.email
    assert_redirected_to root_path
  end

  test "duplicate email on sign up is a validation error" do
    assert_no_difference("User.count") do
      post user_registration_path, params: { user: { email: "ADMIN@example.com", password: "secret123", password_confirmation: "secret123" } }
    end
    assert_response :unprocessable_content
  end

  test "guest can browse books" do
    get root_path
    assert_response :success
    get book_path(books(:dune))
    assert_response :success
  end

  test "sign out" do
    sign_in users(:regular)
    delete destroy_user_session_path
    assert_redirected_to root_path
  end
end
