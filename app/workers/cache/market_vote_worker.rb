class Cache::MarketVoteWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find(market_id)
    return if market.blank?

    market.vote(refresh: true)
  end
end
