class CreateTournaments < ActiveRecord::Migration[6.0]
  def change
    create_table :tournaments do |t|
      t.string :title,        null: false
      t.string :description,  null: false
      t.string :slug
      t.string :image_url
      t.integer :network_id,  null: false

      t.timestamps
    end

    add_index :tournaments, :slug, unique: true

    # linking tournaments to markets (many to many)
    create_table :markets_tournaments, id: false do |t|
      t.belongs_to :market
      t.belongs_to :tournament

      t.timestamps
    end
  end
end
