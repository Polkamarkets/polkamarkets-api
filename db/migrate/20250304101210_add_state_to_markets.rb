class AddStateToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :state, :integer
  end
end
