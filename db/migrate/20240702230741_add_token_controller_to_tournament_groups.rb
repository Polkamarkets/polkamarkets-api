class AddTokenControllerToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :token_controller_address, :string
  end
end
