class AddFieldsToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :description, :string
    add_column :users, :website_url, :string
    add_column :users, :google_connected, :boolean, default: false
  end
end
