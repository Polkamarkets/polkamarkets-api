class AddRankByToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :rank_by, :string
  end
end
