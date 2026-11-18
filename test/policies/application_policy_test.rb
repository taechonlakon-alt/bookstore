require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  test "denies every action by default, even for admins" do
    [ nil, users(:regular), users(:admin) ].each do |u|
      policy = ApplicationPolicy.new(u, Book)
      %i[index? show? create? new? update? edit? destroy?].each do |action|
        assert_not policy.public_send(action), "#{action} for #{u&.email.inspect}"
      end
    end
  end

  test "scope must be defined by subclasses" do
    error = assert_raises(NoMethodError) { ApplicationPolicy::Scope.new(users(:admin), Book).resolve }
    assert_match "You must define #resolve", error.message
  end
end
