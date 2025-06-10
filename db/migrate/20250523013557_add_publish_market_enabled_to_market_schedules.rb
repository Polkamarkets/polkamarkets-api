class AddPublishMarketEnabledToMarketSchedules < ActiveRecord::Migration[6.0]
  def change
    add_column :market_schedules, :publish_market_enabled, :boolean, default: false
  end
end
