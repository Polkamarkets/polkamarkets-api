class AddOgImageUrlToResources < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :og_image_url, :string
    add_column :tournament_groups, :og_image_url, :string
    add_column :tournaments, :og_image_url, :string
  end
end
