class AddStreaksToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :streaks_enabled, :boolean, default: false
    add_column :tournament_groups, :streaks_config, :jsonb, default: {}
  end
end
