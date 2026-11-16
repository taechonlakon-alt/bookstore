require "test_helper"

class ActiveAdminResourcesTest < ActionDispatch::IntegrationTest
  test "admin opens every index" do
    sign_in users(:admin)
    [ admin_books_path, admin_categories_path, admin_markets_path, admin_users_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "admin opens every show page" do
    sign_in users(:admin)
    [ admin_book_path(books(:dune)), admin_category_path(categories(:fiction)),
      admin_market_path(markets(:central)), admin_user_path(users(:regular)) ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "admin opens new and edit forms" do
    sign_in users(:admin)
    [ new_admin_book_path, edit_admin_book_path(books(:dune)), new_admin_category_path,
      new_admin_market_path, edit_admin_market_path(markets(:central)),
      new_admin_user_path, edit_admin_user_path(users(:regular)) ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "admin opens the dashboard with counts and recent books" do
    sign_in users(:admin)
    get admin_root_path
    assert_response :success
    assert_select "a[href=?]", admin_book_path(books(:dune)), text: "Dune"
  end

  test "regular user cannot write by URL" do
    sign_in users(:regular)
    assert_no_difference("Book.count") { delete admin_book_path(books(:dune)) }
    assert_redirected_to root_path
    assert_no_difference("Category.count") { post admin_categories_path, params: { category: { name: "X" } } }
    post batch_action_admin_books_path, params: { batch_action: "destroy", collection_selection: [ books(:dune).id ] }
    assert Book.exists?(books(:dune).id)
  end

  test "admin creates a book with markets" do
    sign_in users(:admin)
    post admin_books_path, params: { book: { title: "New", author: "A", category_id: categories(:fiction).id, market_ids: [ markets(:central).id ] } }
    assert_equal [ "Central" ], Book.find_by(title: "New").markets.pluck(:name)
  end

  test "admin creates a user with a role" do
    sign_in users(:admin)
    post admin_users_path, params: { user: { email: "aa@example.com", password: "secret123", password_confirmation: "secret123", role: "admin" } }
    assert User.find_by(email: "aa@example.com").admin?
  end

  test "admin edits own email without a password" do
    sign_in users(:admin)
    patch admin_user_path(users(:admin)), params: { user: { email: "boss@example.com", password: "", password_confirmation: "", role: "admin" } }
    assert_equal "boss@example.com", users(:admin).reload.email
  end

  test "admin stays signed in after changing own password" do
    sign_in users(:admin)
    patch admin_user_path(users(:admin)), params: { user: { password: "newsecret123", password_confirmation: "newsecret123", role: "admin" } }
    assert users(:admin).reload.valid_password?("newsecret123")
    get admin_root_path
    assert_response :success
  end

  test "admin cannot demote or delete themselves" do
    sign_in users(:admin)
    patch admin_user_path(users(:admin)), params: { user: { role: "user" } }
    assert users(:admin).reload.admin?
    assert_redirected_to admin_user_path(users(:admin))
    assert_equal "You cannot change your own role", flash[:alert]
    assert_no_difference("User.count") { delete admin_user_path(users(:admin)) }
  end

  test "users index hides the delete link on the admin's own row" do
    sign_in users(:admin)
    get admin_users_path
    assert_select "a[href=?]", admin_user_path(users(:regular)), text: "Delete"
    assert_select "a[href=?]", admin_user_path(users(:admin)), text: "Delete", count: 0
  end

  test "batch delete including the admin's own user is refused" do
    sign_in users(:admin)
    assert_no_difference("User.count") do
      post batch_action_admin_users_path, params: { batch_action: "destroy", collection_selection: [ users(:admin).id, users(:regular).id ] }
    end
  end

  test "batch delete refuses the whole batch when the admin's own user comes last" do
    sign_in users(:admin)
    assert_no_difference("User.count") do
      post batch_action_admin_users_path, params: { batch_action: "destroy", collection_selection: [ users(:regular).id, users(:admin).id ] }
    end
    assert_redirected_to admin_users_path
    assert_equal "You cannot delete your own account", flash[:alert]
  end

  test "batch delete removes only other users" do
    sign_in users(:admin)
    assert_difference("User.count", -1) do
      post batch_action_admin_users_path, params: { batch_action: "destroy", collection_selection: [ users(:regular).id ] }
    end
    assert_redirected_to admin_users_path
  end

  test "regular user cannot batch delete users" do
    sign_in users(:regular)
    assert_no_difference("User.count") do
      post batch_action_admin_users_path, params: { batch_action: "destroy", collection_selection: [ users(:admin).id ] }
    end
  end

  test "admin can delete another user" do
    sign_in users(:admin)
    assert_difference("User.count", -1) { delete admin_user_path(users(:regular)) }
  end

  test "category with books cannot be deleted" do
    sign_in users(:admin)
    assert_no_difference("Category.count") { delete admin_category_path(categories(:fiction)) }
    assert_redirected_to admin_categories_path
    assert_match(/books/i, flash[:alert])
  end

  test "ransack does not expose password fields" do
    assert_not_includes User.ransackable_attributes, "encrypted_password"
    assert_not_includes User.ransackable_attributes, "reset_password_token"
  end
end
