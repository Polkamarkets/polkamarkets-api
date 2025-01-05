class AddClaimReceiverAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :claims, :receiver_address, :string
  end
end
