module Api
  class UsersController < BaseController
    before_action :authenticate_user!, except: [:register_waitlist, :redeem_code]

    def register_waitlist
      raise 'Email not found' if params[:email].blank?
      raise 'Email is invalid' unless params[:email] =~ URI::MailTo::EMAIL_REGEXP
      raise 'Name not found' if params[:name].blank?

      if User.find_by(email: params[:email])
        return render json: { error: 'Email already registered' }, status: :bad_request
      end

      # register email to brevo
      brevo_service = BrevoService.new
      brevo_service.register_contact(email: params[:email], name: params[:name])

      # create user
      User.create!(email: params[:email], username: params[:name])

      render json: { success: true }, status: :ok
    end

    def redeem_code
      raise 'Redeem code not found' if params[:code].blank?

      user = User.find_by!(redeem_code: params[:code])
      if user.whitelisted
        return render json: { error: 'User already whitelisted' }, status: :bad_request
      end

      user.update(whitelisted: true)

      render json: { success: true }, status: :ok
    end

    def update
      # create dictionary of params to update
      update_data = {}

      if params[:login_type].present?
        update_data['login_type'] = params[:login_type]
      end

      if params[:legacy].present?
        update_data['wallet_address'] = params[:wallet_address] if params[:wallet_address].present?
      elsif current_user.wallet_address.nil?
        if current_user.login_type == 'wallet'
          update_data['wallet_address'] = current_user.login_public_key
        else
          particle_service = ParticleService.new
          smart_account_address = particle_service.get_smart_account_addres(address: current_user.login_public_key)

          update_data['wallet_address'] = smart_account_address
        end
      end

      if current_user.avatar.blank? && params[:avatar].present?
        update_data['avatar'] = params[:avatar]
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

      if params[:origin].present?
        update_data['origin'] = params[:origin]
      end

      current_user.update(update_data)

      render json: { user: current_user }, status: :ok
    end
  end
end
