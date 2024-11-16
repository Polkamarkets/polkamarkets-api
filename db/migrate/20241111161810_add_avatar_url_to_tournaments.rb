class AddAvatarUrlToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :avatar_url, :string
  end
end
