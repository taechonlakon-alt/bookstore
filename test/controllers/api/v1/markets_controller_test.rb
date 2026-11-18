require "test_helper"

class Api::V1::MarketsControllerTest < ActionDispatch::IntegrationTest
  test "index includes books" do
    sign_in users(:regular)
    get api_v1_markets_path, as: :json
    central = response.parsed_body.find { _1["name"] == "Central" }
    assert_equal %w[Cosmos Dune], central["books"].map { _1["title"] }.sort
  end

  test "non-admin cannot delete" do
    sign_in users(:regular)
    assert_no_difference("Market.count") { delete api_v1_market_path(markets(:central)), as: :json }
    assert_response :forbidden
  end

  test "admin creates a market with books" do
    sign_in users(:admin)
    post api_v1_markets_path, params: { market: { name: "Night", book_ids: [ books(:cosmos).id ] } }, as: :json
    assert_response :created
    assert_equal [ "Cosmos" ], response.parsed_body["books"].map { _1["title"] }
  end

  test "admin replaces a market's books and deletes it" do
    sign_in users(:admin)
    patch api_v1_market_path(markets(:central)), params: { market: { book_ids: [] } }, as: :json
    assert_response :ok
    assert_equal [], response.parsed_body["books"]

    delete api_v1_market_path(markets(:central)), as: :json
    assert_equal "Market deleted", response.parsed_body["message"]
  end

  test "unknown market is 404" do
    sign_in users(:regular)
    get api_v1_market_path(id: 999_999), as: :json
    assert_equal "Market not found", response.parsed_body["error"]
  end

  test "show includes books" do
    sign_in users(:regular)
    get api_v1_market_path(markets(:central)), as: :json
    assert_response :ok
    assert_equal "Central", response.parsed_body["name"]
    assert_equal %w[Cosmos Dune], response.parsed_body["books"].map { _1["title"] }.sort
  end

  test "blank or duplicate name gives 422" do
    sign_in users(:admin)
    assert_no_difference("Market.count") { post api_v1_markets_path, params: { market: { name: "" } }, as: :json }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Name can't be blank"

    other = Market.create!(name: "Other")
    patch api_v1_market_path(other), params: { market: { name: "Central" } }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Name has already been taken"
  end

  test "update or delete unknown id is 404" do
    sign_in users(:admin)
    patch api_v1_market_path(id: 999_999), params: { market: { name: "X" } }, as: :json
    assert_response :not_found
    delete api_v1_market_path(id: 999_999), as: :json
    assert_response :not_found
  end
end
