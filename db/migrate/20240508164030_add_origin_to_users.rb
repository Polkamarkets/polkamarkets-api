class AddOriginToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :origin, :string
  end
end
