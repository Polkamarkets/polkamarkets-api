class AddTradingViewSymbolToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :trading_view_symbol, :string
  end
end
