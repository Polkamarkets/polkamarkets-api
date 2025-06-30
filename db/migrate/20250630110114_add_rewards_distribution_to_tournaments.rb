class AddRewardsDistributionToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :auto_distribute_rewards, :boolean, default: false
    add_column :tournaments, :rewards_token_address, :string
    add_column :tournaments, :rewards_distributed, :boolean, default: false
    add_column :tournaments, :rewards_distribution, :jsonb, default: {}
    add_column :tournaments, :rewards_distribution_tx_id, :string
  end
end
