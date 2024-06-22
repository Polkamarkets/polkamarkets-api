class AddMetadataUrlToTournamentsAndTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :metadata_url, :string
    add_column :tournament_groups, :metadata_url, :string
  end
end
