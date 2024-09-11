class AddSymbolAndAdminsToTournamentGroup < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :symbol, :string
    add_column :tournament_groups, :admins, :jsonb, default: []
  end
end
