require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  test "non-admin cannot read users" do
    sign_in_as users(:regular)
    get api_v1_users_path, as: :json
    assert_response :forbidden
    get api_v1_user_path(users(:regular)), as: :json
    assert_response :forbidden
  end

  test "admin lists and shows users without password digests" do
    sign_in_as users(:admin)
    get api_v1_users_path, as: :json
    assert_response :ok
    assert_equal %w[created_at email_address id role], response.parsed_body.first.keys.sort
    assert_no_match "password", response.body

    get api_v1_user_path(users(:regular)), as: :json
    assert_equal "regular@example.com", response.parsed_body["email_address"]
  end

  test "admin creates a user who can log in" do
    sign_in_as users(:admin)
    post api_v1_users_path, params: { user: { email_address: "api@example.com", password: "secret123", password_confirmation: "secret123", role: "user" } }, as: :json
    assert_response :created
    assert_no_match "password", response.body
    assert User.find_by(email_address: "api@example.com").authenticate("secret123")
  end

  test "duplicate email gives 422" do
    sign_in_as users(:admin)
    post api_v1_users_path, params: { user: { email_address: "ADMIN@example.com", password: "p", password_confirmation: "p" } }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Email address has already been taken"
  end

  test "admin updates a role and deletes a user" do
    sign_in_as users(:admin)
    patch api_v1_user_path(users(:regular)), params: { user: { role: "admin" } }, as: :json
    assert_response :ok
    assert users(:regular).reload.admin?

    assert_difference("User.count", -1) { delete api_v1_user_path(users(:regular)), as: :json }
    assert_equal "User deleted", response.parsed_body["message"]
  end

  test "invalid role gives 422 json" do
    sign_in_as users(:admin)
    post api_v1_users_path, params: { user: { email_address: "r@example.com", password: "p", password_confirmation: "p", role: "boss" } }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Role is not included in the list"
  end

  test "admin cannot delete themselves" do
    sign_in_as users(:admin)
    assert_no_difference("User.count") { delete api_v1_user_path(users(:admin)), as: :json }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "You cannot delete your own account"
  end

  test "admin cannot change their own role" do
    sign_in_as users(:admin)
    patch api_v1_user_path(users(:admin)), params: { user: { role: "user" } }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "You cannot change your own role"
    assert users(:admin).reload.admin?
  end

  test "admin can still update their own email" do
    sign_in_as users(:admin)
    patch api_v1_user_path(users(:admin)), params: { user: { email_address: "boss@example.com", role: "admin" } }, as: :json
    assert_response :ok
    assert_equal "boss@example.com", users(:admin).reload.email_address
  end
end
