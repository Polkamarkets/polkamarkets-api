class AddFieldsToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :short_description, :string
    add_column :tournament_groups, :website_url, :string
    add_column :tournament_groups, :published, :boolean, default: false
  end
end
