class AddServerAndAvatarToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :discord_servers, :jsonb
    add_column :users, :avatar, :string
  end
end
