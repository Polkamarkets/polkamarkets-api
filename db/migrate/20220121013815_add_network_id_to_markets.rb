class AddNetworkIdToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :network_id, :integer

    # setting a default value so column can be not null (should be updated manually)
    Market.update_all(network_id: -1) if defined?(Market)

    # change not null constraints
    change_column_null :markets, :network_id, false
  end
end
