class RefactorMoreActivityIndexes < ActiveRecord::Migration[6.0]
  def change
    remove_index :activities, [:action, :timestamp, :address]
    remove_index :activities, [:action, :created_at, :address]
    remove_index :activities, [:network_id, :token_address, :created_at, :address]

    add_index :activities, [:network_id, :market_id, :action]
  end
end
