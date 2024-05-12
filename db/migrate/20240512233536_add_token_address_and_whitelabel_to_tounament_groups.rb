class AddTokenAddressAndWhitelabelToTounamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :token_address, :string
    add_column :tournament_groups, :whitelabel, :boolean, default: false
  end
end
