class MoveUserRoleToRolify < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO roles (name, created_at, updated_at)
      VALUES ('admin', NOW(), NOW()), ('user', NOW(), NOW())
    SQL

    execute <<~SQL
      INSERT INTO users_roles (user_id, role_id)
      SELECT users.id, roles.id
      FROM users
      JOIN roles ON roles.name = users.role
        AND roles.resource_type IS NULL
        AND roles.resource_id IS NULL
    SQL

    remove_column :users, :role
  end

  def down
    add_column :users, :role, :string, default: "user", null: false

    execute <<~SQL
      UPDATE users SET role = 'admin'
      WHERE EXISTS (
        SELECT 1 FROM users_roles
        JOIN roles ON roles.id = users_roles.role_id
        WHERE users_roles.user_id = users.id
          AND roles.name = 'admin'
          AND roles.resource_type IS NULL
          AND roles.resource_id IS NULL
      )
    SQL

    execute <<~SQL
      DELETE FROM users_roles
      WHERE role_id IN (
        SELECT id FROM roles
        WHERE name IN ('admin', 'user') AND resource_type IS NULL AND resource_id IS NULL
      )
    SQL
    execute "DELETE FROM roles WHERE name IN ('admin', 'user') AND resource_type IS NULL AND resource_id IS NULL"
  end
end
