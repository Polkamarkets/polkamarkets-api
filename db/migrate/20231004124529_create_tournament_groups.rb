class CreateTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :tournament_groups do |t|
      t.string :title, null: false
      t.string :description, null: false
      t.string :slug
      t.integer :position

      t.timestamps
    end

    add_index :tournament_groups, :slug, unique: true

    add_reference :tournaments, :tournament_group, foreign_key: true

    add_column :tournaments, :position, :integer
  end
end
