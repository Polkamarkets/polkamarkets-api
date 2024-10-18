class RemoveUniqueIndexFromActivities < ActiveRecord::Migration[6.0]
  def change
    # unique network_id, tx_id, action index is not longer valid
    remove_index :activities, [:network_id, :tx_id, :action]

    # adding more indexes for optimization purposes
    add_index :activities, [:market_id, :network_id]
    add_index :activities, [:timestamp, :network_id]
    add_index :activities, :timestamp
  end
end
