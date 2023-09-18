class CreateRewards < ActiveRecord::Migration[6.0]
  def change
    create_table :rewards do |t|
      t.integer "epoch", null: false
      t.string "timeframe", null: false
      t.string "token_address", null: false
      t.integer "network_id", null: false
      t.jsonb "merkle_tree", null: false
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
    end
  end
end
