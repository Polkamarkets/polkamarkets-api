class CreatePortfolios < ActiveRecord::Migration[6.0]
  def change
    create_table :portfolios do |t|
      t.string :eth_address, null: false

      t.timestamps
    end

    add_index :portfolios, [:eth_address], unique: true
  end
end
