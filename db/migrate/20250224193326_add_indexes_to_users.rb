class AddIndexesToUsers < ActiveRecord::Migration[6.0]
  def change
    add_index :users, [:wallet_address]
    add_index :users, [:created_at]
  end
end
