class AddClaimTokenAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :claims, :token_address, :string
  end
end
