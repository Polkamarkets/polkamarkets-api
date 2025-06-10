class AddTemplateVariablesToMarketSchedules < ActiveRecord::Migration[6.0]
  def change
    add_column :market_schedules, :template_variables, :jsonb, default: {}
  end
end
