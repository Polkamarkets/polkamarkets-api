class AddOnboardedToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :onboarded, :boolean, default: false, null: false
  end
end
