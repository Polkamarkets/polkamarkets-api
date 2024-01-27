class UserOperation::CheckStatusWorker
  include Sidekiq::Worker

  def perform(user_operation_id)
    user_operation = UserOperation.find_by(id: user_operation_id)
    return if user_operation.blank?

    return if user_operation.success?

    user_operation_logs = EtherscanService.new(user_operation.network_id).logs(
      UserOperation::ENTRY_POINT,
      [
        UserOperation::EVENT_TOPIC,
        user_operation.user_operation_hash
      ]
    )

    if user_operation_logs.present?
      transaction_hash = user_operation_logs.first['transactionHash']
      return user_operation.update(status: :success, transaction_hash: transaction_hash)
    end

    # setting to failed if user_operation is older than 1h
    if user_operation.created_at < 1.hour.ago
      user_operation.update(status: :failed, error_message: 'transaction processing timeout')
    end
  end
end
