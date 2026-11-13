require "test_helper"

class Api::V1::BooksControllerTest < ActionDispatch::IntegrationTest
  test "guest gets 401 json" do
    get api_v1_books_path, as: :json
    assert_response :unauthorized
    assert_equal "Unauthorized", response.parsed_body["error"]

    post api_v1_books_path, params: { book: { title: "X", category_id: categories(:fiction).id } }, as: :json
    assert_response :unauthorized
  end

  test "logged-in user can read" do
    sign_in_as! users(:regular)
    get api_v1_books_path, as: :json
    assert_response :ok
    assert_includes response.parsed_body.map { _1["title"] }, "Dune"

    get api_v1_book_path(books(:dune)), as: :json
    assert_response :ok
    body = response.parsed_body
    assert_equal %w[author category description id markets title], body.keys.sort
    assert_equal "Fiction", body["category"]["name"]
    assert_equal %w[Central Online], body["markets"].map { _1["name"] }.sort
  end

  test "unknown id is 404 with message" do
    sign_in_as! users(:regular)
    get api_v1_book_path(id: 999_999), as: :json
    assert_response :not_found
    assert_equal "Book not found", response.parsed_body["error"]
  end

  test "non-admin cannot write" do
    sign_in_as! users(:regular)
    assert_no_difference("Book.count") do
      post api_v1_books_path, params: { book: { title: "X", category_id: categories(:fiction).id } }, as: :json
      assert_response :forbidden
      assert_equal "Forbidden", response.parsed_body["error"]
      delete api_v1_book_path(books(:dune)), as: :json
      assert_response :forbidden
    end
    patch api_v1_book_path(books(:dune)), params: { book: { title: "Hacked" } }, as: :json
    assert_response :forbidden
    assert_equal "Dune", books(:dune).reload.title
  end

  test "admin creates, updates and deletes" do
    sign_in_as! users(:admin)
    post api_v1_books_path, params: { book: { title: "New", category_id: categories(:fiction).id } }, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    assert_equal "Fiction", response.parsed_body["category"]["name"]

    patch api_v1_book_path(id), params: { book: { title: "Newer" } }, as: :json
    assert_response :ok
    assert_equal "Newer", response.parsed_body["title"]

    delete api_v1_book_path(id), as: :json
    assert_response :ok
    assert_equal "Book deleted", response.parsed_body["message"]
    assert_not Book.exists?(id)
  end

  test "invalid book gives 422 with errors" do
    sign_in_as! users(:admin)
    post api_v1_books_path, params: { book: { title: "" } }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Title can't be blank"

    patch api_v1_book_path(books(:dune)), params: { book: { title: "" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "update or delete unknown id is 404" do
    sign_in_as! users(:admin)
    patch api_v1_book_path(id: 999_999), params: { book: { title: "X" } }, as: :json
    assert_response :not_found
    delete api_v1_book_path(id: 999_999), as: :json
    assert_response :not_found
  end
end
