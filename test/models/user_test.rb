require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new users get the user role" do
    user = User.create!(email: "n@example.com", password: "secret123")
    assert_equal %w[user], user.roles.pluck(:name)
    assert_equal "user", user.role
  end

  test "role= replaces the role, never two" do
    user = users(:regular)
    user.update!(role: "admin")
    assert_equal %w[admin], user.reload.roles.pluck(:name)
    assert user.admin?
  end

  test "email is downcased and stripped" do
    assert_equal "x@example.com", User.create!(email: " X@Example.com ", password: "secret123").email
  end

  test "role= with the current role changes nothing" do
    user = users(:admin)
    user.role = "user"
    user.role = "admin"
    user.save!
    assert_equal %w[admin], user.reload.roles.pluck(:name)
  end

  test "a failed validation leaves roles untouched" do
    user = users(:regular)
    assert_not user.update(role: "boss")
    assert_equal %w[user], user.reload.roles.pluck(:name)
  end

  test "admin fixture is admin" do
    assert users(:admin).admin?
  end

  test "email must be unique ignoring case" do
    assert_not User.new(email: "ADMIN@example.com", password: "password").valid?
  end

  test "email is required" do
    assert_not User.new(password: "password").valid?
  end

  test "invalid role is a validation error, not an exception" do
    user = User.new(email: "r@example.com", password: "secret123", role: "boss")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end
end
