class AddImageFieldsToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :image_url, :string
    add_column :tournament_groups, :banner_url, :string
  end
end
