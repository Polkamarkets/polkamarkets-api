class CreateVotes < ActiveRecord::Migration[6.0]
  def change
    create_table :votes do |t|
      t.integer :upvotes, default: 0
      t.integer :downvotes, default: 0
      t.references :market, null: false, foreign_key: true, index: { unique: true }
    end
  end
end
