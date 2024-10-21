class AddScheduledAtToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :scheduled_at, :datetime
  end
end
