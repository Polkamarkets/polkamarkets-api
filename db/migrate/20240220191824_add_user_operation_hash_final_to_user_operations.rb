class AddUserOperationHashFinalToUserOperations < ActiveRecord::Migration[6.0]
  def change
    add_column :user_operations, :user_operation_hash_final, :string
  end
end
