module Api
  class UsersController < BaseController
    before_action :authenticate_user!

    def update

      # create dictionary of params to update
      update_data = {
        'login_type' => params[:login_type],
        'avatar' => params[:avatar]
      }

      if current_user.wallet_address.nil?
        update_data['wallet_address'] = params[:wallet_address]
      end

      if params[:login_type] == 'discord' && params[:oauth_access_token]
        # get username and servers from discord
        discord_service = DiscordService.new
        username = discord_service.get_username(token: params[:oauth_access_token])
        unless username.nil?
          update_data['username'] = username
        end

        servers = discord_service.get_servers(token: params[:oauth_access_token])
        unless servers.nil?
          update_data['discord_servers'] = servers
        end

        # revoke token to allow new login
        discord_service.revoke_token(token: params[:oauth_access_token])
      end

      current_user.update(update_data)

      render json: { update: 'ok' }, status: :ok
    end
  end
end
