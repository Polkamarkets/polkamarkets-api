class Cache::MarketVotesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find(market_id)
    return if market.blank?

    market.votes(refresh: true)
  end
end
