class AddTokenAddressIndexToActivities < ActiveRecord::Migration[6.0]
  def change
    add_index :activities, [:token_address]
  end
end
