require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "requires a name" do
    assert_not Category.new.valid?
  end

  test "name must be unique" do
    assert_not Category.new(name: categories(:fiction).name).valid?
  end

  test "cannot be destroyed while it has books" do
    assert_not categories(:fiction).destroy
    assert Category.exists?(categories(:fiction).id)
  end
end
