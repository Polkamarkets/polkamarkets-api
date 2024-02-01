class UserOperation::SendToBundlerWorker
  include Sidekiq::Worker

  def perform(user_operation_id)
    user_operation = UserOperation.find_by(id: user_operation_id)
    return if user_operation.blank?

    response = nil

    # trying 3 times to send the operation with 1 second intervals
    tries = 3
    tries.times do
      response = BundlerService.new.process_user_operation(user_operation.user_operation, user_operation.network_id)
      break if response.dig('error').blank?

      user_operation.update(retries: user_operation.retries + 1)
      sleep 1
    end

    if response.dig('error').present?
      user_operation.update(status: :failed, error_message: "#{response.dig('error', 'code')}: #{response.dig('error', 'message')}")
    end
  end
end
