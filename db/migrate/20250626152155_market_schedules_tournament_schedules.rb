class MarketSchedulesTournamentSchedules < ActiveRecord::Migration[6.0]
  def change
    create_join_table :market_schedules, :tournament_schedules do |t|
      t.index [:market_schedule_id, :tournament_schedule_id], unique: true, name: 'index_market_schedules_tournament_schedules_on_schedule_ids'

      t.timestamps
    end
  end
end
