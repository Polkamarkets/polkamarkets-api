class RemoveIndexesFromActivities < ActiveRecord::Migration[6.0]
  def change
    remove_index :activities, name: 'index_activities_on_network_market_action_address'
    remove_index :activities, name: 'index_activities_on_network_market_action_timestamp'
    remove_index :activities, name: 'index_activities_on_network_market_address_timestamp'
    remove_index :activities, name: 'index_activities_on_network_market_action_timestamp_address'
    remove_index :activities, [:network_id, :market_id, :timestamp]
    remove_index :activities, [:network_id, :market_id, :address]
  end
end
