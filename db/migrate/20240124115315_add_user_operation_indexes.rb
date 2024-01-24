class AddUserOperationIndexes < ActiveRecord::Migration[6.0]
  def change
    add_index :user_operations, [:network_id, :user_address]
    add_index :user_operations, :user_address
    add_index :user_operations, :user_operation_hash, unique: true
  end
end
