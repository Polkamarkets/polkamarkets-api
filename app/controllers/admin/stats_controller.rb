module Admin
  class StatsController < BaseController

    def index
      stats = Ethereum::PredictionMarketContractService.new.stats(market_id: market&.eth_market_id)

      render json: stats, status: :ok
    end

    private

    def market
      return nil if params[:market_id].blank?

      @market ||= Market.find_by_slug_or_eth_market_id(params[:market_id])
    end
  end
end
