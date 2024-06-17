class AddFieldsToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :resolution_title, :string
    add_column :markets, :resolution_source, :string
    add_column :markets, :topics, :string, array: true, default: []
  end
end
