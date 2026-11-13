require "test_helper"

class Admin::BooksControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is blocked from admin page and changes" do
    sign_in_as! users(:regular)
    get admin_root_path
    assert_redirected_to root_path
    assert_equal "Admins only.", flash[:alert]

    assert_no_difference "Book.count" do
      post admin_books_path, params: { book: { title: "X", category_id: categories(:fiction).id } }
      delete admin_book_path(books(:dune))
    end
    patch admin_book_path(books(:dune)), params: { book: { title: "Hacked" } }
    assert_equal "Dune", books(:dune).reload.title
  end

  test "admin link shows in navbar only for admins" do
    sign_in_as! users(:regular)
    get root_path
    assert_select "a[href=?]", admin_root_path, count: 0

    sign_in_as! users(:admin)
    get root_path
    assert_select "a[href=?]", admin_root_path
  end

  test "admin sees admin page" do
    sign_in_as! users(:admin)
    get admin_root_path
    assert_response :success
    assert_select "a[href=?]", admin_books_path
  end

  test "admin sees book list with edit and delete" do
    sign_in_as! users(:admin)
    get admin_books_path
    assert_select "a[href=?]", new_admin_book_path
    assert_select "a[href=?]", edit_admin_book_path(books(:dune))
    assert_select "form[action=?][data-turbo-confirm]", admin_book_path(books(:dune))
  end

  test "admin creates a book" do
    sign_in_as! users(:admin)
    get new_admin_book_path
    assert_response :success
    assert_difference "Book.count", 1 do
      post admin_books_path, params: { book: { title: "New", author: "A", category_id: categories(:fiction).id } }
    end
    assert_redirected_to admin_books_path
  end

  test "blank title re-renders with 422" do
    sign_in_as! users(:admin)
    post admin_books_path, params: { book: { title: "", category_id: categories(:fiction).id } }
    assert_response :unprocessable_entity
    assert_match "Title can&#39;t be blank", response.body
  end

  test "admin edits a book" do
    sign_in_as! users(:admin)
    get edit_admin_book_path(books(:dune))
    assert_response :success
    patch admin_book_path(books(:dune)), params: { book: { title: "Dune 2" } }
    assert_redirected_to admin_books_path
    assert_equal "Dune 2", books(:dune).reload.title
  end

  test "blank title on edit re-renders with 422" do
    sign_in_as! users(:admin)
    patch admin_book_path(books(:dune)), params: { book: { title: "" } }
    assert_response :unprocessable_entity
  end

  test "admin deletes a book" do
    sign_in_as! users(:admin)
    assert_difference "Book.count", -1 do
      delete admin_book_path(books(:dune))
    end
    assert_redirected_to admin_books_path
  end
end
