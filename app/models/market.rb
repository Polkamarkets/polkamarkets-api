class Market < ApplicationRecord
  validates_presence_of :title, :category

  has_many :outcomes, class_name: "MarketOutcome", dependent: :destroy

  validates :outcomes, length: { minimum: 2, maximum: 2 } # currently supporting only binary markets

  scope :published, -> { where('published_at < ?', DateTime.now).where.not(eth_market_id: nil) }
  scope :open, -> { published.where('expires_at > ?', DateTime.now) }
  scope :resolved, -> { published.where('expires_at < ?', DateTime.now) }

  def eth_data(refresh = false)
    return nil if eth_market_id.blank?

    return @eth_data if @eth_data.present? && !refresh

    Rails.cache.fetch("markets:#{eth_market_id}", expires_in: 24.hours, force: refresh) do
      @eth_data = Ethereum::PredictionMarketContractService.new.get_market(eth_market_id)
    end
  end

  def outcome_prices(timeframe, candles: 12, refresh: false)
    return nil if eth_market_id.blank?

    market_prices =
      Rails.cache.fetch("markets:#{eth_market_id}:prices", expires_in: 24.hours, force: refresh) do
        Ethereum::PredictionMarketContractService.new.get_price_events(eth_market_id)
      end

    market_prices.group_by { |price| price[:outcome_id] }.map do |outcome_id, prices|
      chart_data_service = ChartDataService.new(prices, :price)
      # returning in hash form
      [outcome_id, chart_data_service.chart_data_for(timeframe, candles)]
    end.to_h
  end

  def action_events(address: nil, refresh: false)
    return nil if eth_market_id.blank?

    # TODO: review caching both globally and locally

    market_actions =
      Rails.cache.fetch("markets:#{eth_market_id}:actions", expires_in: 24.hours, force: refresh) do
        Ethereum::PredictionMarketContractService.new.get_action_events(market_id: eth_market_id)
      end

    market_actions.select do |action|
      address.blank? || action[:address].downcase == address.downcase
    end
  end

  def refresh_cache!
    # triggering a refresh for all cached ethereum data
    eth_data(true)
    outcome_prices('1h', refresh: true)
    action_events(refresh: true)
  end
end
