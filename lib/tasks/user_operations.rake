namespace :user_operations do
  desc "checks for new markets and creates them"
  task :check_pending_operations, [:symbol] => :environment do |task, args|
    return if Rails.application.config_for(:ethereum).bundler_url.blank? ||
      Rails.application.config_for(:ethereum).bundler_entry_point.blank?

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      pending_user_operations = UserOperation.pending.where(network_id: network_id)

      # fetching last user_operations from etherscan
      begin
        latest_user_operations = UserOperation.fetch_latest_logs(network_id)
        pending_user_operations.each do |user_operation|
          log = latest_user_operations.find do |log|
            log['topics'].include?(user_operation.user_operation_hash)
          end

          next if log.blank?

          user_operation.update(status: :success, transaction_hash: log['transactionHash'])
        end
      rescue => e
        # shouldn't be a blocker
      end
    end
  end

  task :check_pending_operations_atomic, [:symbol] => :environment do |task, args|
    return if Rails.application.config_for(:ethereum).bundler_url.blank? ||
      Rails.application.config_for(:ethereum).bundler_entry_point.blank?

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      pending_user_operations = UserOperation.pending.where(network_id: network_id)
      pending_user_operations.each do |user_operation|
        # awaiting 0.2s between each request due to rate limiting
        sleep(0.2)
        UserOperation::CheckStatusWorker.set(queue: 'priority').perform_async(user_operation.id)
      end
    end
  end
end
