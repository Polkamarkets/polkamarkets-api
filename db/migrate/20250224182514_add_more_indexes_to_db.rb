class AddMoreIndexesToDb < ActiveRecord::Migration[6.0]
  def change
    add_index :activities, [:created_at]
    add_index :activities, [:action, :created_at, :address]
    add_index :tournament_groups, [:title]
  end
end
