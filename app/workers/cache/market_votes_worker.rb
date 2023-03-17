class Cache::MarketVotesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    current_delta = market.votes_delta

    market.votes(refresh: true)

    new_delta = market.votes_delta

    # if delta changed, we need to clean the market cache
    if current_delta != new_delta
      Cache::MarketCacheSerializerDeleteWorker.new.perform(market.id)
    end
  end
end
