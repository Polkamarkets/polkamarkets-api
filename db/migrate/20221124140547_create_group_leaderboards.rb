class CreateGroupLeaderboards < ActiveRecord::Migration[6.0]
  def change
    create_table :group_leaderboards do |t|
      t.string :title,        null: false
      t.string :slug
      t.string :created_by,   null: false
      t.jsonb :users,         default: []

      t.timestamps

      t.index [:slug], unique: true
    end
  end
end
