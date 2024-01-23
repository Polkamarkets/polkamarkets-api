class CreateUserOperations < ActiveRecord::Migration[6.0]
  def change
    create_table :user_operations do |t|
      t.integer :network_id, null: false
      t.integer :status, null: false, default: 0

      t.string :user_address, null: false
      t.string :user_operation_hash, null: false
      t.jsonb :user_operation, null: false
      t.jsonb :user_operation_data, null: false

      t.string :tx_id

      t.timestamps
    end
  end
end
