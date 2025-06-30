class MarketResolutionWorker
  include Sidekiq::Worker

  def perform(market_resolution_id)
    MarketResolutionService.new(market_resolution_id).resolve_market
  end
end
