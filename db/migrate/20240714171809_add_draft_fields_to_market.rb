class AddDraftFieldsToMarket < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :draft_liquidity, :integer
    add_column :markets, :draft_timeout, :integer
  end
end
