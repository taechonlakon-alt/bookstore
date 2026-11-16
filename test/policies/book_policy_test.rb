require "test_helper"

class BookPolicyTest < ActiveSupport::TestCase
  test "everyone can read, only admin can write" do
    [ nil, users(:regular), users(:admin) ].each do |u|
      assert BookPolicy.new(u, books(:dune)).show?
      assert BookPolicy.new(u, Book).index?
    end
    %i[create? update? destroy?].each do |action|
      assert_not BookPolicy.new(nil, books(:dune)).public_send(action)
      assert_not BookPolicy.new(users(:regular), books(:dune)).public_send(action)
      assert BookPolicy.new(users(:admin), books(:dune)).public_send(action)
    end
  end
end
