class ChangeMarketItemsToMarketOutcomes < ActiveRecord::Migration[6.0]
  def change
    rename_table :market_items, :market_outcomes
    add_column :market_outcomes, :eth_market_id, :integer
  end
end
