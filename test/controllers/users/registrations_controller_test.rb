require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "admin cannot cancel their own account" do
    sign_in users(:admin)
    assert_no_difference("User.count") { delete user_registration_path }
    assert_redirected_to edit_user_registration_path
    assert_equal "Admins cannot delete their own account.", flash[:alert]
  end

  test "regular user can cancel their own account" do
    sign_in users(:regular)
    assert_difference("User.count", -1) { delete user_registration_path }
    assert_redirected_to root_path
  end
end
