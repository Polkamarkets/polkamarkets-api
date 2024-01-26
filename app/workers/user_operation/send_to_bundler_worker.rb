class UserOperation::SendToBundlerWorker
  include Sidekiq::Worker

  def perform(user_operation_id)
    user_operation = UserOperation.find_by(id: user_operation_id)
    return if user_operation.blank?

    response = BundlerService.new.process_user_operation(user_operation.user_operation, user_operation.network_id)

    if response.dig('error').present?
      user_operation.update(status: :failed)
    end
  end
end
