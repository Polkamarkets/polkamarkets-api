module Api
  class UserOperationsController < BaseController
    def create
      user_operation = UserOperation.new(user_operation_params)

      if !user_operation.save
        return render json: { errors: user_operation.errors }, status: :unprocessable_entity
      end

      response = BundlerService.new.process_user_operation(user_operation.user_operation, user_operation.network_id)

      if response.dig('error').present?
        user_operation.update(status: :failed)
      end

      render json: response
    end

    private

    def user_operation_params
      params.require(:user_operation).permit(
        :network_id,
        :tx_id,
        :user_operation_hash,
        user_operation: {},
        user_operation_data: [:contract, :method, :arguments]
      )
    end
  end
end
