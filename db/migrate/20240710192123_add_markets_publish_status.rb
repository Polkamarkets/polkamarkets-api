class AddMarketsPublishStatus < ActiveRecord::Migration[6.0]
  def change
    add_column :markets, :publish_status, :integer, default: 0
  end
end
