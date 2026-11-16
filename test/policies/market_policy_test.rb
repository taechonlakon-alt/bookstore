require "test_helper"

class MarketPolicyTest < ActiveSupport::TestCase
  test "everyone can read, only admin can write" do
    [ nil, users(:regular), users(:admin) ].each do |u|
      assert MarketPolicy.new(u, markets(:central)).show?
      assert MarketPolicy.new(u, Market).index?
    end
    %i[create? update? destroy?].each do |action|
      assert_not MarketPolicy.new(nil, markets(:central)).public_send(action)
      assert_not MarketPolicy.new(users(:regular), markets(:central)).public_send(action)
      assert MarketPolicy.new(users(:admin), markets(:central)).public_send(action)
    end
  end
end
