class AddRedeemCodeToLands < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :redeem_code, :string
  end
end
