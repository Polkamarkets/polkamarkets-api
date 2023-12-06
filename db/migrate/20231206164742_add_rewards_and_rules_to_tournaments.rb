class AddRewardsAndRulesToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :rewards, :text
    add_column :tournaments, :rules, :text
  end
end
