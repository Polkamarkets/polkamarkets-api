class AddTitleAndDescriptionToAchievements < ActiveRecord::Migration[6.0]
  def change
    add_column :achievements, :verified, :boolean, default: false
    add_column :achievements, :title, :string
    add_column :achievements, :description, :string
  end
end
