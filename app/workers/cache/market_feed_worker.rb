class Cache::MarketFeedWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    market.feed(refresh: true)
  end
end
