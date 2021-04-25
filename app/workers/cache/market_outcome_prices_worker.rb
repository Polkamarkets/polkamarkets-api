class Cache::MarketOutcomePricesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find(market_id)
    return if market.blank?

    market.outcome_prices('1h', refresh: true)
  end
end
