class CreateTournamentTemplatesAndSchedules < ActiveRecord::Migration[6.0]
  def change
    create_table :tournament_templates do |t|
      t.jsonb :template, null: false
      t.integer :template_type

      t.timestamps
    end

    create_table :tournament_schedules do |t|
      t.references :tournament_template, null: false, foreign_key: true
      t.jsonb :tournament_variables, default: {}
      t.integer :frequency, null: false
      t.datetime :starts_at, null: false
      t.datetime :last_run_at
      t.boolean :active, default: true
      t.datetime :expires_at
      t.datetime :resolves_at
      t.jsonb :template_variables, default: {}

      t.timestamps
    end
  end
end
