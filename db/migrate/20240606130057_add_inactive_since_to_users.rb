class AddInactiveSinceToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :inactive_since, :datetime
  end
end
