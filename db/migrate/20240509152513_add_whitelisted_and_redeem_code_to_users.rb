class AddWhitelistedAndRedeemCodeToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :whitelisted, :boolean, default: false
    add_column :users, :redeem_code, :string
  end
end
