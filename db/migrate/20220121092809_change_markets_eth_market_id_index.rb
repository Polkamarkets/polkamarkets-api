class ChangeMarketsEthMarketIdIndex < ActiveRecord::Migration[6.0]
  def change
    remove_index :markets, :eth_market_id

    add_index :markets, [:eth_market_id, :network_id], unique: true
  end
end
