class AddFeaturedAtToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :featured_at, :datetime
  end
end
