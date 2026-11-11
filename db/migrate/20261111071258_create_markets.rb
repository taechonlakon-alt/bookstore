class CreateMarkets < ActiveRecord::Migration[8.1]
  def change
    create_table :markets do |t|
      t.string :name

      t.timestamps
    end
  end
end
