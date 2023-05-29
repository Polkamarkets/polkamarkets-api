module Api
  class UsersController < BaseController
    before_action :authenticate_user!

    def update

      # create dictionary of params to update
      
      update_data = {
        'login_type' => params[:login_type],
        'discord_servers' => params[:discord_servers],
        'avatar' => params[:avatar]
      }

      if current_user.username.nil?
        update_data['username'] = params[:username]
      end

      if current_user.wallet_address.nil?
        update_data['wallet_address'] = params[:wallet_address]
      end

      current_user.update(update_data)

      render json: { update: 'ok' }, status: :ok
    end
  end
end
