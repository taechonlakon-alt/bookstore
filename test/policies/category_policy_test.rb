require "test_helper"

class CategoryPolicyTest < ActiveSupport::TestCase
  test "everyone can read, only admin can write" do
    [ nil, users(:regular), users(:admin) ].each do |u|
      assert CategoryPolicy.new(u, categories(:fiction)).show?
      assert CategoryPolicy.new(u, Category).index?
    end
    %i[create? update? destroy?].each do |action|
      assert_not CategoryPolicy.new(nil, categories(:fiction)).public_send(action)
      assert_not CategoryPolicy.new(users(:regular), categories(:fiction)).public_send(action)
      assert CategoryPolicy.new(users(:admin), categories(:fiction)).public_send(action)
    end
  end
end
