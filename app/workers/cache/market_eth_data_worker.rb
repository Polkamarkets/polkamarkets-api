class Cache::MarketEthDataWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find(market_id)
    return if market.blank?

    market.eth_data(true)
  end
end
