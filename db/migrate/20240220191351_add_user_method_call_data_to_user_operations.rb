class AddUserMethodCallDataToUserOperations < ActiveRecord::Migration[6.0]
  def change
    add_column :user_operations, :user_method_call_data, :string
  end
end
