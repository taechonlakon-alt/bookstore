require "test_helper"

class Admin::MarketsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is blocked" do
    sign_in_as! users(:regular)
    get admin_markets_path
    assert_redirected_to root_path
    assert_no_difference("Market.count") { post admin_markets_path, params: { market: { name: "X" } } }
  end

  test "admin sees markets with edit and delete" do
    sign_in_as! users(:admin)
    get admin_markets_path
    assert_response :success
    assert_select "a[href=?]", new_admin_market_path
    assert_select "a[href=?]", edit_admin_market_path(markets(:central))
    assert_select "form[action=?][data-turbo-confirm]", admin_market_path(markets(:central))
  end

  test "admin creates a market with books" do
    sign_in_as! users(:admin)
    post admin_markets_path, params: { market: { name: "Night", book_ids: [ "", books(:cosmos).id ] } }
    assert_redirected_to admin_markets_path
    assert_equal [ books(:cosmos) ], Market.find_by!(name: "Night").books.to_a
  end

  test "admin edits a market's name and books" do
    sign_in_as! users(:admin)
    get edit_admin_market_path(markets(:online))
    assert_response :success
    patch admin_market_path(markets(:online)), params: { market: { name: "Web", book_ids: [ "", books(:cosmos).id ] } }
    assert_redirected_to admin_markets_path
    assert_equal "Web", markets(:online).reload.name
    assert_equal [ books(:cosmos) ], markets(:online).books.to_a
  end

  test "unticking every book clears the market" do
    sign_in_as! users(:admin)
    patch admin_market_path(markets(:central)), params: { market: { name: "Central", book_ids: [ "" ] } }
    assert_equal 0, markets(:central).reload.books.count
  end

  test "blank name re-renders with 422" do
    sign_in_as! users(:admin)
    post admin_markets_path, params: { market: { name: "" } }
    assert_response :unprocessable_entity
    assert_match "Name can&#39;t be blank", response.body
  end

  test "admin deletes a market" do
    sign_in_as! users(:admin)
    assert_difference("Market.count", -1) { delete admin_market_path(markets(:online)) }
    assert_redirected_to admin_markets_path
  end

  test "form shows a checkbox per book and dashboard links to markets" do
    sign_in_as! users(:admin)
    get new_admin_market_path
    assert_select "input[type=checkbox][name=?]", "market[book_ids][]", count: Book.count
    assert_select "input[type=hidden][name=?][value=?]", "market[book_ids][]", ""
    get edit_admin_market_path(markets(:central))
    assert_select "input[type=checkbox][value=?][checked]", books(:dune).id.to_s
    get admin_root_path
    assert_select "a[href=?]", admin_markets_path
  end
end
