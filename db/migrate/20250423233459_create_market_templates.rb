class CreateMarketTemplates < ActiveRecord::Migration[6.0]
  def change
    create_table :market_templates do |t|
      t.jsonb :template, null: false

      t.timestamps
    end
  end
end
