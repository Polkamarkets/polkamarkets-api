class AddRankByPriority < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :rank_by_priority, :string
  end
end
