require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  test "guests are sent to login" do
    get book_path(books(:dune))
    assert_redirected_to new_session_path
  end

  test "lists all books with category buttons" do
    sign_in_as! users(:regular)
    get root_path
    assert_select "a[href=?]", book_path(books(:dune))
    assert_select "a[href=?]", book_path(books(:cosmos))
    assert_select "a[href=?]", books_path(category_id: categories(:science).id)
  end

  test "category filter" do
    sign_in_as! users(:regular)
    get books_path(category_id: categories(:science).id)
    assert_select "a[href=?]", book_path(books(:cosmos))
    assert_select "a[href=?]", book_path(books(:dune)), count: 0
  end

  test "search" do
    sign_in_as! users(:regular)
    get books_path(q: "cos")
    assert_select "a[href=?]", book_path(books(:cosmos))
    assert_select "a[href=?]", book_path(books(:dune)), count: 0
  end

  test "no matches" do
    sign_in_as! users(:regular)
    get books_path(q: "zzz")
    assert_match "No books found", response.body
  end

  test "details page" do
    sign_in_as! users(:regular)
    get book_path(books(:dune))
    assert_select "h1", "Dune"
    assert_match "Frank Herbert", response.body
  end
end
