class AddOgThemeToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :og_theme, :string
  end
end
