require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is blocked" do
    sign_in_as users(:regular)
    get new_admin_user_path
    assert_redirected_to root_path
    assert_no_difference("User.count") do
      post admin_users_path, params: { user: { email_address: "x@example.com", password: "p", password_confirmation: "p", role: "admin" } }
    end
    assert_redirected_to root_path
  end

  test "admin creates a user who can log in" do
    sign_in_as users(:admin)
    get new_admin_user_path
    assert_response :success
    assert_difference("User.count", 1) do
      post admin_users_path, params: { user: { email_address: "new@example.com", password: "secret123", password_confirmation: "secret123", role: "user" } }
    end
    assert_redirected_to admin_users_path
    user = User.find_by(email_address: "new@example.com")
    assert user.user?
    assert user.authenticate("secret123")
  end

  test "admin can create another admin" do
    sign_in_as users(:admin)
    post admin_users_path, params: { user: { email_address: "boss@example.com", password: "p", password_confirmation: "p", role: "admin" } }
    assert User.find_by(email_address: "boss@example.com").admin?
  end

  test "duplicate email re-renders with 422" do
    sign_in_as users(:admin)
    assert_no_difference("User.count") do
      post admin_users_path, params: { user: { email_address: "ADMIN@example.com", password: "p", password_confirmation: "p", role: "user" } }
    end
    assert_response :unprocessable_entity
    assert_match "Email address has already been taken", response.body
  end

  test "mismatched password confirmation re-renders with 422" do
    sign_in_as users(:admin)
    post admin_users_path, params: { user: { email_address: "z@example.com", password: "a", password_confirmation: "b", role: "user" } }
    assert_response :unprocessable_entity
    assert_match "Password confirmation doesn&#39;t match", response.body
  end

  test "user list shows users, never password digests" do
    sign_in_as users(:admin)
    get admin_users_path
    assert_response :success
    assert_match "regular@example.com", response.body
    assert_no_match "$2a$", response.body
    assert_select "a[href=?]", new_admin_user_path
  end

  test "dashboard links to users" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_select "a[href=?]", admin_users_path
  end

  test "invalid role re-renders with 422" do
    sign_in_as users(:admin)
    post admin_users_path, params: { user: { email_address: "r@example.com", password: "p", password_confirmation: "p", role: "boss" } }
    assert_response :unprocessable_entity
  end
end
