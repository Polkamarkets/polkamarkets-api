class Cache::MarketLiquidityPricesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    market.liquidity_prices('24h', refresh: true)
  end
end
