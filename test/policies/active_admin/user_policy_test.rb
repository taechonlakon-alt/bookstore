require "test_helper"

class ActiveAdmin::UserPolicyTest < ActiveSupport::TestCase
  test "admin can destroy another user" do
    assert ActiveAdmin::UserPolicy.new(users(:admin), users(:regular)).destroy?
  end

  test "admin cannot destroy themselves" do
    assert_not ActiveAdmin::UserPolicy.new(users(:admin), users(:admin)).destroy?
  end

  test "regular user cannot destroy" do
    assert_not ActiveAdmin::UserPolicy.new(users(:regular), users(:admin)).destroy?
  end

  test "destroy_all is admin only" do
    assert_not ActiveAdmin::ApplicationPolicy.new(users(:regular), Book).destroy_all?
    assert ActiveAdmin::ApplicationPolicy.new(users(:admin), Book).destroy_all?
  end

  test "scope is empty for a regular user and complete for an admin" do
    assert_empty ActiveAdmin::ApplicationPolicy::Scope.new(users(:regular), Book).resolve
    assert_equal Book.count, ActiveAdmin::ApplicationPolicy::Scope.new(users(:admin), Book).resolve.count
  end
end
