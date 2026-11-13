require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "requires a title" do
    assert_not Book.new(category: categories(:fiction)).valid?
  end

  test "search is case-insensitive" do
    assert_equal [ books(:dune) ], Book.search("DUNE").to_a
  end

  test "in_category filters" do
    assert_equal [ books(:cosmos) ], Book.in_category(categories(:science).id).to_a
  end

  test "blank filters return all" do
    assert_equal Book.count, Book.search("").in_category(nil).count
  end
end
