class Market < ApplicationRecord
  def self.ransackable_attributes(_auth_object = nil)
    %w[name created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  has_many :market_books, dependent: :destroy
  has_many :books, through: :market_books

  validates :name, presence: true, uniqueness: true
end
