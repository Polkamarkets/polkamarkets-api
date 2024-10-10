class Cache::MarketRefreshPricesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    market.eth_data(refresh: true)
    market.refresh_serializer_cache!
  end
end
