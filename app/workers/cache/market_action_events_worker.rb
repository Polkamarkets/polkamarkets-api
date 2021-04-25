class Cache::MarketActionEventsWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find(market_id)
    return if market.blank?

    market.action_events(refresh: true)
  end
end
