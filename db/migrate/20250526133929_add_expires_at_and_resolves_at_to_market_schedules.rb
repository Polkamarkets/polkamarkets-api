class AddExpiresAtAndResolvesAtToMarketSchedules < ActiveRecord::Migration[6.0]
  def change
    add_column :market_schedules, :expires_at, :datetime
    add_column :market_schedules, :resolves_at, :datetime
  end
end
