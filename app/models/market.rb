class Market < ApplicationRecord
  has_many :market_books, dependent: :destroy
  has_many :books, through: :market_books

  validates :name, presence: true, uniqueness: true
end
