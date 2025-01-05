class ChangeClaimsAmountToFloat < ActiveRecord::Migration[6.0]
  def change
    change_column :claims, :amount, :float
  end
end
