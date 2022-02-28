class CreateAchievements < ActiveRecord::Migration[6.0]
  def change
    create_table :achievements do |t|
      t.integer :eth_id, null: false
      t.integer :network_id, null: false
      t.integer :action, null: false
      t.integer :occurrences, null: false
      t.string  :image_url

      t.timestamps
    end

    add_index :achievements, [:eth_id, :network_id], unique: true
  end
end
