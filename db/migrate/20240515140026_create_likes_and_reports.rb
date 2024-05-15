class CreateLikesAndReports < ActiveRecord::Migration[6.0]
  def change
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false

      t.timestamps
    end

    create_table :reports do |t|
      t.references :user, foreign_key: true
      t.references :reportable, polymorphic: true, null: false
      t.text :content

      t.timestamps
    end
  end
end
