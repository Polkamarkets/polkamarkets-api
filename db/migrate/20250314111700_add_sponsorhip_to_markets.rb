class AddSponsorhipToMarkets < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :sponsorship, :jsonb, default: {}
  end
end
