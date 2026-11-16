require "test_helper"

class StorefrontAssetsTest < ActionDispatch::IntegrationTest
  test "storefront does not link the admin stylesheet" do
    get root_path
    assert_select "link[rel=stylesheet][href*='active_admin']", count: 0
  end
end
