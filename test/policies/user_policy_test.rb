require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "only admin can do anything with users" do
    %i[index? show? create? update? destroy?].each do |action|
      assert_not UserPolicy.new(users(:regular), users(:regular)).public_send(action)
      assert UserPolicy.new(users(:admin), users(:regular)).public_send(action)
    end
  end
end
