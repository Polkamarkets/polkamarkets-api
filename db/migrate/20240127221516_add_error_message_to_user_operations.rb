class AddErrorMessageToUserOperations < ActiveRecord::Migration[6.0]
  def change
    add_column :user_operations, :error_message, :string
  end
end
