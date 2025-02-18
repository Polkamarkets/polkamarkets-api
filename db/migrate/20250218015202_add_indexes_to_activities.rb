class AddIndexesToActivities < ActiveRecord::Migration[6.0]
  def change
    add_index :activities, :network_id
    add_index :activities, [:tx_id, :network_id]
    add_index :activities, [:network_id, :market_id, :address]
    add_index :activities, [:network_id, :market_id, :action]
    add_index :activities, [:network_id, :market_id, :timestamp]
    add_index :activities, [:network_id, :market_id, :action, :address], name: 'index_activities_on_network_market_action_address'
    add_index :activities, [:network_id, :market_id, :action, :timestamp], name: 'index_activities_on_network_market_action_timestamp'
    add_index :activities, [:network_id, :market_id, :address, :timestamp], name: 'index_activities_on_network_market_address_timestamp'
    add_index :activities, [:network_id, :market_id, :action, :timestamp, :address], name: 'index_activities_on_network_market_action_timestamp_address'
  end
end
