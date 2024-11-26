class AddClaimOwnerAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :claims, :owner_address, :string
  end
end
