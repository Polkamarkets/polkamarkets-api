class AddReportedToReports < ActiveRecord::Migration[6.0]
  def change
    add_column :reports, :reported, :boolean, default: false
  end
end
