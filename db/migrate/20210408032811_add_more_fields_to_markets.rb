class AddMoreFieldsToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :eth_market_id, :integer
  end
end
