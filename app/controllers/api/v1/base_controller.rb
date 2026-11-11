class Api::V1::BaseController < ApplicationController
  skip_forgery_protection

  private

  # Answer with JSON instead of redirecting to the login page.
  def request_authentication
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def require_admin
    render json: { error: "Forbidden" }, status: :forbidden unless Current.user.admin?
  end
end
