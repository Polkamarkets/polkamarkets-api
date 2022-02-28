class Achievement < ApplicationRecord
  validates_presence_of :eth_id, :network_id, :action, :occurrences
  validates_uniqueness_of :eth_id, scope: :network_id

  enum action: {
    buy: 0,
    add_liquidity: 1,
    bond: 2,
    claim_winnings: 3,
    create_market: 4,
  }

  def action_events(refresh: false)
    return @eth_data if @eth_data.present? && !refresh

    @eth_data ||=
      Rails.cache.fetch("achievements:network_#{network_id}:data", force: refresh) do
        Bepro::AchievementsContractService.new(network_id: network_id).get_action_events(address: eth_address)
      end
  end

  def refresh_cache!
    # disabling cache delete for now
    # $redis_store.keys("portfolios:#{eth_address}*").each { |key| $redis_store.del key }

    # triggering a refresh for all cached ethereum data
    Cache::PortfolioActionEventsWorker.perform_async(id)
    Cache::PortfolioHoldingsWorker.perform_async(id)
    Cache::PortfolioLiquidityFeesWorker.perform_async(id)
  end
end
