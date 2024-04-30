class AddTopicsToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :topics, :jsonb, default: []
  end
end
