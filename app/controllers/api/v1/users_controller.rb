class Api::V1::UsersController < Api::V1::BaseController
  before_action :require_admin

  def index
    users = User.order(:id)
    render json: users, **json_options, status: :ok
  end

  def show
    user = User.find_by(id: params[:id])

    if user.present?
      render json: user, **json_options, status: :ok
    else
      render json: { error: "User not found" }, status: :not_found
    end
  end

  def create
    user = User.new(user_params)

    if user.save
      render json: user, **json_options, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    user = User.find_by(id: params[:id])
    return render json: { error: "User not found" }, status: :not_found if user.nil?

    if user == Current.user && user_params.key?(:role) && user_params[:role] != user.role
      return render json: { errors: [ "You cannot change your own role" ] }, status: :unprocessable_entity
    end

    if user.update(user_params)
      render json: user, **json_options, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find_by(id: params[:id])
    return render json: { error: "User not found" }, status: :not_found if user.nil?

    if user == Current.user
      return render json: { errors: [ "You cannot delete your own account" ] }, status: :unprocessable_entity
    end

    if user.destroy
      render json: { message: "User deleted" }, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation, :role ])
  end

  def json_options
    { only: [ :id, :email_address, :role, :created_at ] }
  end
end
