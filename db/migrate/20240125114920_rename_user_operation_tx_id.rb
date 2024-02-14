class RenameUserOperationTxId < ActiveRecord::Migration[6.0]
  def change
    rename_column :user_operations, :tx_id, :transaction_hash
  end
end
