class CreateInitialTables < ActiveRecord::Migration[6.0]
  def change
    create_table :markets do |t|
      t.string :title,        null: false
      t.string :description

      t.string :category,     null: false
      t.string :subcategory

      t.datetime :published_at
      t.datetime :expires_at

      t.timestamps
    end

    create_table :market_items do |t|
      t.references :market, null: false, foreign_key: true
      t.string :title, null: false

      t.timestamps
    end

    add_index :market_items, [:market_id, :title], unique: true
  end
end
