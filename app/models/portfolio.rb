class Portfolio < ApplicationRecord
  validates_presence_of :eth_address

  before_validation :normalize_eth_address

  validate :eth_address_validation

  def normalize_eth_address
    # setting default to downcase to avoid case duplicates
    self.eth_address = self.eth_address.downcase
  end

  def eth_address_validation
    unless eth_address.match(/0[x,X][a-fA-F0-9]{40}$/)
      errors.add(:eth_address, 'Invalid ETH address')
    end
  end

  def action_events(refresh: false)
    return @market_actions if @market_actions.present? && !refresh

    @market_actions ||=
      Rails.cache.fetch("portfolios:#{eth_address}:actions", expires_in: 24.hours, force: refresh) do
        Ethereum::PredictionMarketContractService.new.get_action_events(address: eth_address)
      end
  end

  def portfolio_market_ids
    action_events.map { |event| event[:market_id] }.uniq.sort.reverse
  end

  def holdings(refresh: false)
    return @holdings if @holdings.present? && !refresh

    @holdings ||=
      Rails.cache.fetch("portfolios:#{eth_address}:holdings", expires_in: 24.hours, force: refresh) do
        portfolio_market_ids.map do |market_id|
          Ethereum::PredictionMarketContractService.new.get_user_market_shares(market_id, eth_address)
        end
      end
  end

  def refresh_cache!
    # triggering a refresh for all cached ethereum data
    holdings(refresh: true)
    action_events(refresh: true)
  end
end
