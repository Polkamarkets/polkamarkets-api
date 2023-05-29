module Api
  class UsersController < BaseController
    before_action :authenticate_user!

    def update
      username = params[:username]
      wallet_address = params[:wallet_address]
      login_type = params[:login_type]
      discord_servers = params[:discord_servers]
      avatar = params[:avatar]

      current_user.update(
        username: username,
        wallet_address: wallet_address,
        login_type: login_type,
        discord_servers: discord_servers,
        avatar: avatar
      )

      render json: { update: 'ok' }, status: :ok
    end
  end
end
