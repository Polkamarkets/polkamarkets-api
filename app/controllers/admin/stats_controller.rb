module Admin
  class StatsController < BaseController
    def index
      stats = Rails.application.config_for(:ethereum).network_ids.map do |network_id|
        [
          network_id,
          Bepro::PredictionMarketContractService.new(network_id: network_id).stats(market_id: market&.eth_market_id)
        ]
      end.to_h

      render json: stats, status: :ok
    end

    def leaderboard
      raise 'Leaderboard :: from and to params not set' if params[:from].blank? || params[:to].blank?

      leaderboard = LeaderboardService.new.leaderboard(params[:from].to_i, params[:to].to_i)

      render json: leaderboard, status: :ok
    end

    private

    def market
      return nil if params[:market_id].blank?

      @market ||= Market.find_by_slug_or_eth_market_id(params[:market_id])
    end
  end
end
