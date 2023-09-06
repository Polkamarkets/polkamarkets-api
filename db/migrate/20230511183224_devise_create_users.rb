# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :login_public_key
      t.string :username
      t.string :wallet_address
      t.string :login_type

      t.timestamps null: false
    end
  end
end
