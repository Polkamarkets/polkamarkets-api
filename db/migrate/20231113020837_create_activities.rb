class CreateActivities < ActiveRecord::Migration[6.0]
  def change
    create_table :activities do |t|
      t.integer :network_id
      t.timestamp :timestamp
      t.text :address
      t.text :action
      t.text :tx_id
      t.text :block_number
      t.float :amount
      t.float :shares
      t.integer :market_id
      t.integer :outcome_id

      t.timestamps
    end

    add_index :activities, [:network_id, :tx_id, :action], unique: true
    add_index :activities, :action
    add_index :activities, :address
    add_index :activities, :market_id
  end
end
