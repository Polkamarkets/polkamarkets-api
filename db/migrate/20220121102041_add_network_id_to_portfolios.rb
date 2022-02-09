class AddNetworkIdToPortfolios < ActiveRecord::Migration[6.0]
  def change
    add_column :portfolios, :network_id, :integer

    # setting a default value so column can be not null (should be updated manually)
    Portfolio.update_all(network_id: -1) if defined?(Portfolio)

    # change not null constraints
    change_column_null :portfolios, :network_id, false

    remove_index :portfolios, :eth_address
    add_index :portfolios, [:eth_address, :network_id], unique: true
  end
end
