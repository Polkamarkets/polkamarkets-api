class AddAdvancedToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :advanced, :boolean, default: false
  end
end
