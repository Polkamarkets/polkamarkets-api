class AddRetriesToUserOperations < ActiveRecord::Migration[6.0]
  def change
    add_column :user_operations, :retries, :integer, default: 0
  end
end
