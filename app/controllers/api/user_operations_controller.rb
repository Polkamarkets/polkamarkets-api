module Api
  class UserOperationsController < BaseController
    def index
      raise 'from param is required' unless params[:from].present?

      user_operations = UserOperation.where(user_address: params[:from]).order(created_at: :desc).limit(50)

      render json: user_operations
    end

    def show
      user_operation = UserOperation.find_by!(user_operation_hash: params[:id])

      render json: user_operation
    end

    def create
      user_operation = UserOperation.new(user_operation_params)

      if !user_operation.save
        return render json: { errors: user_operation.errors }, status: :unprocessable_entity
      end

      UserOperation::SendToBundlerWorker.set(queue: 'priority').perform_async(user_operation.id)

      head :ok
    end

    private

    def user_operation_params
      params.require(:user_operation).permit(
        :network_id,
        :tx_id,
        :user_operation_hash,
        user_operation: {},
        user_operation_data: [:contract, :method, arguments: []]
      )
    end
  end
end
