class ChangeMarketsExpiresAtNullable < ActiveRecord::Migration[6.0]
  def change
    change_column_null :markets, :expires_at, false
  end
end
