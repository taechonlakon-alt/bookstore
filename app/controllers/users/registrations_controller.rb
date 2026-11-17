class Users::RegistrationsController < Devise::RegistrationsController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_user_registration_path, alert: "Try again later." }

  def destroy
    if current_user.admin?
      redirect_to edit_user_registration_path, alert: "Admins cannot delete their own account."
    else
      super
    end
  end
end
