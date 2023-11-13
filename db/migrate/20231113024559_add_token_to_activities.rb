class AddTokenToActivities < ActiveRecord::Migration[6.0]
  def change
    add_column :activities, :token_address, :string
  end
end
