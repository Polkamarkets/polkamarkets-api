class Cache::MarketEthDataWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    market.eth_data(refresh: true)
    market.resolved_at(refresh: true)
    market.edit_history(refresh: true)
  end
end
