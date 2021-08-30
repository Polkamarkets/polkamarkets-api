class AddVerifiedToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :verified, :boolean, default: false
  end
end
