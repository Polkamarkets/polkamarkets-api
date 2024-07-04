class AddTournamentGroupsUsersTable < ActiveRecord::Migration[6.0]
  def change
    create_join_table :tournament_groups, :users do |t|
      t.index [:tournament_group_id, :user_id], unique: true, name: 'index_tg_users_on_tg_id_and_user_id'

      t.timestamps
    end

    add_column :tournament_groups, :users_count, :integer, default: 0
  end
end
