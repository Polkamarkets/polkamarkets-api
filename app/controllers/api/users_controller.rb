module Api
  class UsersController < BaseController
    before_action :authenticate_user!, except: [:register_waitlist, :redeem_code]

    before_action :set_paper_trail_whodunnit

    def register_waitlist
      raise 'Email not found' if params[:email].blank?
      raise 'Email is invalid' unless params[:email] =~ URI::MailTo::EMAIL_REGEXP
      raise 'Name not found' if params[:name].blank?

      if User.find_by(email: params[:email])
        return render json: { error: 'Email already registered' }, status: :bad_request
      end

      # create user
      user = User.create!(email: params[:email], username: params[:name])

      # register email to brevo
      brevo_service = BrevoService.new
      brevo_service.register_contact(email: params[:email], name: params[:name], redeem_code: user.redeem_code)

      render json: { success: true }, status: :ok
    end

    def redeem_code
      raise 'Redeem code not found' if params[:code].blank?

      tournament_group = TournamentGroup.find_by(redeem_code: params[:code])
      return render json: { success: true }, status: :ok if tournament_group.present?

      user = User.find_by!(redeem_code: params[:code])
      if user.whitelisted
        return render json: { error: 'User already whitelisted' }, status: :bad_request
      end

      user.update(whitelisted: true)

      render json: { success: true }, status: :ok
    end

    def update
      # create dictionary of params to update
      update_data = user_params

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

      # updating last active date
      update_data['inactive_since'] = DateTime.now

      current_user.update(update_data)

      render json: { user: current_user }, status: :ok
    end

    private

    def user_params
      params.permit(
        :login_type,
        :avatar,
        :origin,
        :email,
        :description,
        :website_url,
        :google_connected,
        :slug
      )
    end
  end
end
