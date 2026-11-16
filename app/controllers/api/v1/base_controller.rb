class Api::V1::BaseController < ApplicationController
  skip_forgery_protection
  before_action :authenticate_api_user!

  private

  # Answer with JSON instead of redirecting to the login page.
  def authenticate_api_user!
    render json: { error: "Unauthorized" }, status: :unauthorized unless user_signed_in?
  end

  def require_admin
    render json: { error: "Forbidden" }, status: :forbidden unless current_user.admin?
  end
end
