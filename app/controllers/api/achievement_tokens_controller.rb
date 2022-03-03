module Api
  class AchievementTokensController < BaseController
    def show
      network_id = Rails.application.config_for(:networks)[params[:network].to_sym]
      raise "Network #{params[:network]} is not configured" if network_id.blank?

      # checking if item was already created
      token = AchievementToken.find_by(eth_id: params[:id], network_id: network_id)
      # trying to create, if on blockchain (will raise an error if does not exist)
      token ||= AchievementToken.create_from_eth_id!(network_id, params[:id])

      render json: token.reload, status: :ok
    end
  end
end
