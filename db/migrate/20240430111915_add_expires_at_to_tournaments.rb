class AddExpiresAtToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :expires_at, :datetime
  end
end
