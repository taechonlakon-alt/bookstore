class AddConstraintsToUsersRoles < ActiveRecord::Migration[8.1]
  def change
    remove_index :users_roles, [ :user_id, :role_id ], name: "index_users_roles_on_user_id_and_role_id"
    add_index :users_roles, [ :user_id, :role_id ], unique: true
    add_foreign_key :users_roles, :users, on_delete: :cascade
    add_foreign_key :users_roles, :roles, on_delete: :cascade
  end
end
