class Book < ApplicationRecord
  def self.ransackable_attributes(_auth_object = nil)
    %w[title author category_id created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[category markets]
  end

  belongs_to :category

  has_many :market_books, dependent: :destroy
  has_many :markets, through: :market_books

  validates :title, presence: true

  scope :search, ->(q) { q.present? ? where("title ILIKE ?", "%#{sanitize_sql_like(q)}%") : all }
  scope :in_category, ->(id) { id.present? ? where(category_id: id) : all }
end
