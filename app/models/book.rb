class Book < ApplicationRecord
  belongs_to :category

  validates :title, presence: true

  scope :search, ->(q) { q.present? ? where("title ILIKE ?", "%#{sanitize_sql_like(q)}%") : all }
  scope :in_category, ->(id) { id.present? ? where(category_id: id) : all }
end
