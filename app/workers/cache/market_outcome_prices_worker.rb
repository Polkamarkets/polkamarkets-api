class Cache::MarketOutcomePricesWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find(market_id)
    return if market.blank?

    market.outcome_prices('24h', refresh: true)
    # caching outcome charts
    market.outcomes.each { |outcome| outcome.price_charts(refresh: true) }
  end
end
