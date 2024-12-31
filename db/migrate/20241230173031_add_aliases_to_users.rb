class AddAliasesToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :aliases, :string, array: true, default: []
  end
end
