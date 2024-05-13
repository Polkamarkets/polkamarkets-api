class AddNetworkIdToTounamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :network_id, :string
  end
end
