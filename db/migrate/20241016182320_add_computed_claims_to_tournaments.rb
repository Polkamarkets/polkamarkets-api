class AddComputedClaimsToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :computed_claims, :boolean, default: false
  end
end
