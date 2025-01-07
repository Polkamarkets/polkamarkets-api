class RenameClaimTypeColumn < ActiveRecord::Migration[6.0]
  def change
    rename_column :claims, :type, :claim_type
  end
end
