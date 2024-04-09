class CreateEthEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :eth_events do |t|
      t.string :contract_name, null: false
      t.integer :network_id, null: false
      t.string :event, null: false

      t.string :address, null: false
      t.string :block_hash
      t.integer :block_number, null: false
      t.integer :log_index, null: false
      t.boolean :removed
      t.string :transaction_hash, null: false
      t.integer :transaction_index
      t.string :signature
      t.jsonb :data
      t.jsonb :raw_data

      t.timestamps
    end

    add_index :eth_events, :network_id
    add_index :eth_events, :contract_name
    add_index :eth_events, :event
    add_index :eth_events, :address
    add_index :eth_events, :block_number
    add_index :eth_events,
      [:network_id, :transaction_hash, :log_index],
      unique: true,
      name: 'index_eth_events_on_network_id_transaction_hash_log_index'
  end

  create_table :eth_queries do |t|
    t.string :contract_name, null: false
    t.integer :network_id, null: false
    t.string :event, null: false

    t.string :filter
    t.integer :last_block_number

    t.timestamps
  end

  add_index :eth_queries, :network_id
  add_index :eth_queries, :contract_name
  add_index :eth_queries, :event
  add_index :eth_queries, :last_block_number
  add_index :eth_queries,
    [:network_id, :contract_name, :event, :filter],
    unique: true,
    name: 'index_eth_queries_on_network_id_contract_name_event_filter'

  create_join_table :eth_events, :eth_queries do |t|
    t.index [:eth_event_id, :eth_query_id], unique: true

    t.timestamps
  end
end
