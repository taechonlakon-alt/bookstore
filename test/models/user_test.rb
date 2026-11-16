require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new users default to user role" do
    assert User.create!(email: "n@example.com", password: "password").user?
  end

  test "email is downcased and stripped" do
    assert_equal "x@example.com", User.create!(email: " X@Example.com ", password: "secret123").email
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
    user = User.new(email: "r@example.com", password: "password", role: "boss")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end
end
