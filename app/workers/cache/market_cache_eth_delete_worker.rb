class Cache::MarketCacheEthDeleteWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    # deleting from active serializer cache
    $redis_store.keys("markets:network_#{market.network_id}:#{market.eth_market_id}:*").each { |key| $redis_store.del key }
  end
end
