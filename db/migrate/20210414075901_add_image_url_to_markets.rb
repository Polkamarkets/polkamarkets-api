class AddImageUrlToMarkets < ActiveRecord::Migration[6.0]
  def change
    # TODO: replace for ActiveStorage
    add_column :markets, :image_url, :string
  end
end
