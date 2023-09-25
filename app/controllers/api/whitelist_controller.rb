module Api
  class WhitelistController < BaseController
    def index
      return render json: { error: 'Whitelist not setup' }, status: :bad_request if Rails.application.config_for(:whitelist).values.compact.blank?

      # checking if an address is whitelist for beta testing
      is_whitelisted = WhitelistService.new.is_whitelisted?(params[:item])

      render json: { is_whitelisted: is_whitelisted }, status: :ok
    end
  end
end
