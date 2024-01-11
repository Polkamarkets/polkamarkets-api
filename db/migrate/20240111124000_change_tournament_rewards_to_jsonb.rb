class ChangeTournamentRewardsToJsonb < ActiveRecord::Migration[6.0]
  def change
    remove_column :tournaments, :rewards, :string
    add_column :tournaments, :rewards, :jsonb, default: []
  end
end
