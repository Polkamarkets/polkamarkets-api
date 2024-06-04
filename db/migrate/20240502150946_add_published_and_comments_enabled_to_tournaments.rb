class AddPublishedAndCommentsEnabledToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :published, :boolean, default: false
    add_column :tournaments, :comments_enabled, :boolean, default: true
  end
end
