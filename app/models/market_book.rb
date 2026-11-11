class MarketBook < ApplicationRecord
  belongs_to :market
  belongs_to :book

  validates :book_id, uniqueness: { scope: :market_id }
end
