class AddOffchainResolvedOutcomeIdToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :offchain_resolved_outcome_id, :integer
  end
end
