class AddUniqueToMarketsEthMarketId < ActiveRecord::Migration[6.0]
  def change
    add_index :markets, [:eth_market_id], unique: true
    add_index :market_outcomes, [:market_id, :eth_market_id], unique: true
  end
end
