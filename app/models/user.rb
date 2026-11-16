class User < ApplicationRecord
  ROLES = %w[admin user].freeze

  def self.ransackable_attributes(_auth_object = nil)
    %w[email created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[roles]
  end

  rolify
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  validates :role, inclusion: { in: ROLES }

  after_save :sync_role

  def role
    @assigned_role || persisted_role
  end

  def role=(value)
    value = value.to_s
    @assigned_role = value == persisted_role ? nil : value
  end

  def admin?
    has_role?(:admin)
  end

  private

  def persisted_role
    admin? ? "admin" : "user"
  end

  def sync_role
    target = @assigned_role || (roles.empty? ? "user" : nil)
    @assigned_role = nil
    return if target.nil?

    self.roles = [ Role.find_or_create_by!(name: target, resource_type: nil, resource_id: nil) ]
  end
end
