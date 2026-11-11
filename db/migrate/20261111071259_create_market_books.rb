class CreateMarketBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :market_books do |t|
      t.references :market, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true

      t.timestamps
    end
    add_index :market_books, [ :market_id, :book_id ], unique: true
  end
end
