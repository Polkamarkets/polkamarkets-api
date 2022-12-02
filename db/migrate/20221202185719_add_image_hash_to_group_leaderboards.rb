class AddImageHashToGroupLeaderboards < ActiveRecord::Migration[6.0]
  def change
    add_column :group_leaderboards, :image_hash, :string
  end
end
