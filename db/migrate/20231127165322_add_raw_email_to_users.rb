class AddRawEmailToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :raw_email, :string
  end
end
