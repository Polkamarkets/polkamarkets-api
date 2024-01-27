namespace :user_operations do
  desc "checks for new markets and creates them"
  task :check_pending_operations, [:symbol] => :environment do |task, args|
    return if Rails.application.config_for(:ethereum).bundler_url.blank? ||
      Rails.application.config_for(:ethereum).bundler_entry_point.blank?

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      pending_user_operations = UserOperation.pending.where(network_id: network_id)
      pending_user_operations.each do |user_operation|
        UserOperation::CheckStatusWorker.set(queue: 'priority').perform_async(user_operation.id)
      end
    end
  end
end
