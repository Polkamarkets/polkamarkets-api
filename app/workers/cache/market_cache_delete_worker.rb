class Cache::MarketCacheDeleteWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    # deleting from active serializer cache
    $redis_store.keys("markets/#{market.id}*").each { |key| $redis_store.del key }
    market.outcomes.each do |outcome|
      $redis_store.keys("market_outcomes/#{outcome.id}*").each { |key| $redis_store.del key }
    end
  end
end
