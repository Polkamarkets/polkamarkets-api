class CreateMarketSchedules < ActiveRecord::Migration[6.0]
  def change
    create_table :market_schedules do |t|
      t.references :market_template, null: false, foreign_key: true
      t.jsonb :market_variables, default: {}
      t.integer :frequency, null: false
      t.datetime :starts_at, null: false
      t.datetime :last_run_at
      t.boolean :active, default: true

      t.timestamps
    end

    add_column :market_templates, :template_type, :integer
  end
end
