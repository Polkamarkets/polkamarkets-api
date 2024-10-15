class AddLogIndexToActivities < ActiveRecord::Migration[6.0]
  def change
    add_column :activities, :log_index, :integer
  end
end
