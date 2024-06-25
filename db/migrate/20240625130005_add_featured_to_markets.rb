class AddFeaturedToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :featured, :boolean, default: false
  end
end
