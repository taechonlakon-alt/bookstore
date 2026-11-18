require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "ransack can search by name only" do
    assert_equal %w[name], Role.ransackable_attributes
    assert_empty Role.ransackable_associations
  end

  test "rejects an unknown resource type" do
    role = Role.new(name: "editor", resource_type: "Nope")
    assert_not role.valid?
    assert role.errors.of_kind?(:resource_type, :inclusion)
  end
end
