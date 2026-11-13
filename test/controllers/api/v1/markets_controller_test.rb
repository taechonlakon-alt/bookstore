require "test_helper"

class Api::V1::MarketsControllerTest < ActionDispatch::IntegrationTest
  test "index includes books" do
    sign_in_as! users(:regular)
    get api_v1_markets_path, as: :json
    central = response.parsed_body.find { _1["name"] == "Central" }
    assert_equal %w[Cosmos Dune], central["books"].map { _1["title"] }.sort
  end

  test "non-admin cannot delete" do
    sign_in_as! users(:regular)
    assert_no_difference("Market.count") { delete api_v1_market_path(markets(:central)), as: :json }
    assert_response :forbidden
  end

  test "admin creates a market with books" do
    sign_in_as! users(:admin)
    post api_v1_markets_path, params: { market: { name: "Night", book_ids: [ books(:cosmos).id ] } }, as: :json
    assert_response :created
    assert_equal [ "Cosmos" ], response.parsed_body["books"].map { _1["title"] }
  end

  test "admin replaces a market's books and deletes it" do
    sign_in_as! users(:admin)
    patch api_v1_market_path(markets(:central)), params: { market: { book_ids: [] } }, as: :json
    assert_response :ok
    assert_equal [], response.parsed_body["books"]

    delete api_v1_market_path(markets(:central)), as: :json
    assert_equal "Market deleted", response.parsed_body["message"]
  end

  test "unknown market is 404" do
    sign_in_as! users(:regular)
    get api_v1_market_path(id: 999_999), as: :json
    assert_equal "Market not found", response.parsed_body["error"]
  end
end
