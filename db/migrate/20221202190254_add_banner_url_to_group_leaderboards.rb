class AddBannerUrlToGroupLeaderboards < ActiveRecord::Migration[6.0]
  def change
    add_column :group_leaderboards, :banner_url, :string
  end
end
