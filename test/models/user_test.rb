require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "new users default to user role" do
    assert User.create!(email_address: "n@example.com", password: "password").user?
  end

  test "admin fixture is admin" do
    assert users(:admin).admin?
  end

  test "email must be unique ignoring case" do
    assert_not User.new(email_address: "ADMIN@example.com", password: "password").valid?
  end

  test "email is required" do
    assert_not User.new(password: "password").valid?
  end

  test "invalid role is a validation error, not an exception" do
    user = User.new(email_address: "r@example.com", password: "password", role: "boss")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end
end
