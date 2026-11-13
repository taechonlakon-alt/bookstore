require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is blocked" do
    sign_in_as users(:regular)
    get admin_categories_path
    assert_redirected_to root_path
    assert_no_difference("Category.count") { post admin_categories_path, params: { category: { name: "X" } } }
  end

  test "admin sees categories with edit and delete" do
    sign_in_as users(:admin)
    get admin_categories_path
    assert_response :success
    assert_select "a[href=?]", new_admin_category_path
    assert_select "a[href=?]", edit_admin_category_path(categories(:fiction))
    assert_select "form[action=?][data-turbo-confirm]", admin_category_path(categories(:fiction))
  end

  test "admin creates, edits and deletes an empty category" do
    sign_in_as users(:admin)
    get new_admin_category_path
    assert_response :success
    post admin_categories_path, params: { category: { name: "Poetry" } }
    assert_redirected_to admin_categories_path
    poetry = Category.find_by!(name: "Poetry")

    get edit_admin_category_path(poetry)
    assert_response :success
    patch admin_category_path(poetry), params: { category: { name: "Poems" } }
    assert_redirected_to admin_categories_path
    assert_equal "Poems", poetry.reload.name

    assert_difference("Category.count", -1) { delete admin_category_path(poetry) }
    assert_redirected_to admin_categories_path
  end

  test "blank name re-renders with 422" do
    sign_in_as users(:admin)
    post admin_categories_path, params: { category: { name: "" } }
    assert_response :unprocessable_entity
    assert_match "Name can&#39;t be blank", response.body
  end

  test "blank name on edit re-renders with 422" do
    sign_in_as users(:admin)
    patch admin_category_path(categories(:fiction)), params: { category: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "deleting a category with books shows an error" do
    sign_in_as users(:admin)
    assert_no_difference("Category.count") { delete admin_category_path(categories(:fiction)) }
    assert_redirected_to admin_categories_path
    assert_match "Cannot delete", flash[:alert]
  end

  test "dashboard links to categories" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_select "a[href=?]", admin_categories_path
  end
end
