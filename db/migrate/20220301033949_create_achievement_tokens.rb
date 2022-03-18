class CreateAchievementTokens < ActiveRecord::Migration[6.0]
  def change
    create_table :achievement_tokens do |t|
      t.references :achievement, null: false, foreign_key: true
      t.integer :eth_id, null: false
      t.integer :network_id, null: false
      t.string  :image_url

      t.timestamps
    end
  end
end
