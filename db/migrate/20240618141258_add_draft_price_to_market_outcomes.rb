class AddDraftPriceToMarketOutcomes < ActiveRecord::Migration[6.0]
  def change
    add_column :market_outcomes, :draft_price, :float
  end
end
