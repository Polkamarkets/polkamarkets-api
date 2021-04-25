class AddOracleSourceToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :oracle_source, :string
  end
end
