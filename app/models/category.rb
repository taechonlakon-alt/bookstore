class Category < ApplicationRecord
  def self.ransackable_attributes(_auth_object = nil)
    %w[name created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  has_many :books, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
