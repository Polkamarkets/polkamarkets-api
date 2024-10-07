class AddIpfsHashFieldToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :image_ipfs_hash, :string
    add_column :market_outcomes, :image_ipfs_hash, :string
  end
end
