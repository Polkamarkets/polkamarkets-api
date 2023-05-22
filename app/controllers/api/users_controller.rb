module Api
  class UsersController < BaseController
    before_action :authenticate_user!

    def update
      username = params[:username]
      wallet_address = params[:wallet_address]
      login_type = params[:login_type]

      current_user.update(
        username: username,
        wallet_address: wallet_address,
        login_type: login_type
      )

      render json: { update: 'ok' }, status: :ok
    end
  end
end
