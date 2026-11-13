require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "show includes books" do
    sign_in_as! users(:regular)
    get api_v1_category_path(categories(:science)), as: :json
    assert_response :ok
    assert_equal "Science", response.parsed_body["name"]
    assert_equal [ "Cosmos" ], response.parsed_body["books"].map { _1["title"] }
  end

  test "non-admin cannot create" do
    sign_in_as! users(:regular)
    assert_no_difference("Category.count") { post api_v1_categories_path, params: { category: { name: "X" } }, as: :json }
    assert_response :forbidden
  end

  test "admin creates, updates and deletes an empty category" do
    sign_in_as! users(:admin)
    post api_v1_categories_path, params: { category: { name: "Poetry" } }, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    patch api_v1_category_path(id), params: { category: { name: "Poems" } }, as: :json
    assert_equal "Poems", response.parsed_body["name"]
    delete api_v1_category_path(id), as: :json
    assert_equal "Category deleted", response.parsed_body["message"]
  end

  test "duplicate name gives 422" do
    sign_in_as! users(:admin)
    post api_v1_categories_path, params: { category: { name: "Fiction" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "deleting a category with books gives 422" do
    sign_in_as! users(:admin)
    assert_no_difference("Category.count") { delete api_v1_category_path(categories(:fiction)), as: :json }
    assert_response :unprocessable_entity
    assert_match "Cannot delete", response.parsed_body["errors"].first
  end

  test "empty list is 200 []" do
    sign_in_as! users(:admin)
    MarketBook.delete_all
    Book.delete_all
    Category.delete_all
    get api_v1_categories_path, as: :json
    assert_response :ok
    assert_equal [], response.parsed_body
  end
end
