module Admin
  class StatsController < BaseController
    def index
      stats = Bepro::PredictionMarketContractService.new.stats(market_id: market&.eth_market_id)

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
