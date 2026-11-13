require "test_helper"

class MarketTest < ActiveSupport::TestCase
  test "requires a name" do
    assert_not Market.new.valid?
  end

  test "name must be unique" do
    assert_not Market.new(name: "Central").valid?
  end

  test "market has many books and book has many markets" do
    assert_equal %w[Cosmos Dune], markets(:central).books.order(:title).pluck(:title)
    assert_equal %w[Central Online], books(:dune).markets.order(:name).pluck(:name)
  end

  test "same book cannot be added twice to a market" do
    assert_not MarketBook.new(market: markets(:online), book: books(:dune)).valid?
  end

  test "deleting a book removes its market links" do
    assert_difference("MarketBook.count", -2) { books(:dune).destroy }
  end

  test "deleting a market keeps the books" do
    assert_no_difference("Book.count") do
      assert_difference("MarketBook.count", -2) { markets(:central).destroy }
    end
  end
end
