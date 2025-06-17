class AddDistributorFieldsToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :draft_distributor_fee, :float
    add_column :markets, :draft_distributor, :string
  end
end
