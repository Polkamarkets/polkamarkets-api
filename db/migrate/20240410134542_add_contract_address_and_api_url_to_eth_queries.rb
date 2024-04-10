class AddContractAddressAndApiUrlToEthQueries < ActiveRecord::Migration[6.0]
  def change
    add_column :eth_queries, :contract_address, :string
    add_column :eth_queries, :api_url, :string

    # backfilling both columns with TODO and reenforcing null constraint
    EthQuery.update_all(contract_address: 'TODO', api_url: 'TODO')
    change_column_null :eth_queries, :contract_address, false
    change_column_null :eth_queries, :api_url, false

    remove_index :eth_queries, name: :index_eth_queries_on_network_id_contract_name_event_filter

    add_index :eth_queries,
      [:network_id, :contract_name, :event, :filter, :contract_address, :api_url],
      unique: true,
      name: 'index_eth_queries_on_network_id_cn_ca_api_url_event_filter'
  end
end
