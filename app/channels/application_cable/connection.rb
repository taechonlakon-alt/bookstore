class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :current_user

  def connect
    self.current_user = find_verified_user || reject_unauthorized_connection
  end

  private
    # Devise stores the signed-in user in Warden, which shares the Rack env with the cable request.
    def find_verified_user
      env["warden"]&.user
    end
end
