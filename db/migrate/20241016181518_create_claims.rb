class CreateClaims < ActiveRecord::Migration[6.0]
  def change
    create_table :claims do |t|
      t.string "network_id", null: false
      t.string "wallet_address", null: false
      t.integer "amount", null: false
      t.datetime "recorded_at", precision: 6, null: true
      t.boolean "claimed", default: false
      t.string "transaction_hash", null: true
      t.string "type", null: false
      t.jsonb "data", null: true
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
    end
  end
end
