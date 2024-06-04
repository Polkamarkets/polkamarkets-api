class UserOperation::CheckStatusWorker
  include Sidekiq::Worker

  def perform(user_operation_id, paginate = false)
    user_operation = UserOperation.find_by(id: user_operation_id)
    return if user_operation.blank?

    return if user_operation.success?

    logs = user_operation.logs(paginate: paginate)

    if logs.present?
      transaction_hash = user_operation.logs_tx_hash
      return user_operation.update(status: :success, transaction_hash: transaction_hash)
    end

    # setting to failed if user_operation is older than 1h
    if user_operation.created_at < 1.hour.ago
      user_operation.update(status: :failed, error_message: 'transaction processing timeout')
    end
  end
end
