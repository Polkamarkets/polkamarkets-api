class RemoveMarketOutcomesMarketIdTitleIndex < ActiveRecord::Migration[6.0]
  def change
    remove_index :market_outcomes, name: :index_market_outcomes_on_market_id_and_title
  end
end
