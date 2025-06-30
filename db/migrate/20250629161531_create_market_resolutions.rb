class CreateMarketResolutions < ActiveRecord::Migration[6.0]
  def change
    add_column :market_schedules, :auto_resolve_enabled, :boolean, default: false

    create_table :market_resolutions do |t|
      t.references :market, null: false, foreign_key: true
      t.references :market_template, null: false, foreign_key: true
      t.references :market_schedule, null: false, foreign_key: true
      t.jsonb :resolution_variables, default: {}
      t.boolean :resolved, default: false

      t.timestamps
    end
  end
end
