ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :role

  includes :roles

  index do
    selectable_column
    id_column
    column :email
    column :role
    column :created_at
    actions
  end

  filter :email
  filter :created_at

  show do
    attributes_table do
      row :email
      row :role
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :email
      f.input :password, hint: (f.object.persisted? ? "Leave blank to keep the current password" : nil)
      f.input :password_confirmation
      f.input :role, as: :select, collection: User::ROLES, include_blank: false
    end
    f.actions
  end

  controller do
    def update
      return redirect_to admin_user_path(resource), alert: "You cannot change your own role" if changing_own_role?

      remove_blank_passwords
      super
      keep_signed_in_after_password_change
    end

    private

    def changing_own_role?
      resource == current_user && params[:user][:role].present? && params[:user][:role] != resource.role
    end

    def remove_blank_passwords
      %i[password password_confirmation].each do |key|
        params[:user].delete(key) if params[:user][key].blank?
      end
    end

    def keep_signed_in_after_password_change
      bypass_sign_in(resource) if resource == current_user && resource.errors.empty? && params[:user][:password].present?
    end
  end
end
