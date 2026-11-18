require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with the user signed in through Devise" do
    connect env: { "warden" => Struct.new(:user).new(users(:regular)) }
    assert_equal users(:regular), connection.current_user
  end

  test "rejects a guest" do
    assert_reject_connection { connect env: { "warden" => Struct.new(:user).new(nil) } }
  end

  test "rejects a request without warden" do
    assert_reject_connection { connect }
  end
end
