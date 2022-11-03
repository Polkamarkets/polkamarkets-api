class Cache::MarketPricesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    market.prices(refresh: true)
  end
end
