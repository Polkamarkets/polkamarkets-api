class AddRefundVoidedMarketsToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :refund_voided_markets, :boolean, default: false
  end
end
