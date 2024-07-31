class CreateUserIdps < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :idp, :string
    add_column :users, :idp_uid, :string

    create_table :user_idps do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :data, default: {}
      t.string :provider
      t.string :uid

      t.timestamps
    end
  end
end
