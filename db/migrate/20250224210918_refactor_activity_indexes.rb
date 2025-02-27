class RefactorActivityIndexes < ActiveRecord::Migration[6.0]
  def change
    remove_index :activities, name: 'index_activities_on_action'
    remove_index :activities, name: 'index_activities_on_address'
    remove_index :activities, name: 'index_activities_on_created_at'
    remove_index :activities, name: 'index_activities_on_market_id'
    remove_index :activities, name: 'index_activities_on_network_id_and_market_id_and_action'
    remove_index :activities, name: 'index_activities_on_timestamp_and_network_id'
    remove_index :activities, name: 'index_activities_on_timestamp'
    remove_index :activities, name: 'index_activities_on_token_address'
    remove_index :activities, name: 'index_activities_on_tx_id_and_network_id'

    add_index :activities, [:action, :timestamp, :address]
    add_index :activities, [:network_id, :token_address, :created_at, :address], name: 'index_activities_on_network_token_created_address'
    add_index :activities, [:network_id, :token_address, :timestamp, :address], name: 'index_activities_on_network_token_timestamp_address'
  end
end
