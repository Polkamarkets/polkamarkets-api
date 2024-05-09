module Api
  class WhitelistController < BaseController
    def index
      return render json: { error: 'Whitelist not setup' }, status: :bad_request if Rails.application.config_for(:whitelist).values.compact.blank?

      # checking if an address is whitelist for beta testing
      is_whitelisted = WhitelistService.new.is_whitelisted?(params[:item])

      if !is_whitelisted
        # also checking db
        is_whitelisted = !!User.find_by(email: params[:item])&.whitelisted
      end

      render json: { is_whitelisted: is_whitelisted }, status: :ok
    end
  end
end
