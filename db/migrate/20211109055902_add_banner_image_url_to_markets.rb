class AddBannerImageUrlToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :banner_url, :string
  end
end
