class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  enum :role, { user: "user", admin: "admin" }, default: "user", validate: true
end
