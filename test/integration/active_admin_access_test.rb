require "test_helper"

class ActiveAdminAccessTest < ActionDispatch::IntegrationTest
  test "guest is sent to sign in" do
    get admin_root_path
    assert_redirected_to new_user_session_path
  end

  test "regular user is refused" do
    sign_in users(:regular)
    get admin_root_path
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "admin sees the dashboard" do
    sign_in users(:admin)
    get admin_root_path
    assert_response :success
  end
end
