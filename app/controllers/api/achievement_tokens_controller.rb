module Api
  class AchievementTokensController < BaseController
    def show
      network_id = Rails.application.config_for(:networks)[params[:network].to_sym]
      raise "Network #{params[:network]} is not configured" if network_id.blank?

      # finding items by eth id
      token = AchievementToken.find_by!(eth_id: params[:id], network_id: network_id)

      render json: token, status: :ok
    end
  end
end
