class Cache::MarketCacheSerializerRefreshWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    Cache::MarketCacheSerializerDeleteWorker.new.perform(market_id)
    # triggering a serializer action to set cache
    MarketSerializer.new(market).as_json
  end
end
