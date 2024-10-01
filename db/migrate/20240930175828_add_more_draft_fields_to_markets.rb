class AddMoreDraftFieldsToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :draft_fee, :float
    add_column :markets, :draft_treasury_fee, :float
    add_column :markets, :draft_treasury, :string
  end
end
