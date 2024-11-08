class AddScheduleTriesToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :schedule_tries, :integer, default: 0
  end
end
