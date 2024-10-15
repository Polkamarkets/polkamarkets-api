class AddNetworkIdTxIdLogIndexIndexToActivities < ActiveRecord::Migration[6.0]
  def change
    add_index :activities, %i[network_id tx_id log_index]
  end
end
