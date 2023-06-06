class AddImageUrlToMarketOutcomes < ActiveRecord::Migration[6.0]
  def change
    add_column :market_outcomes, :image_url, :string
  end
end
