class Market < ApplicationRecord
  include Immutable

  validates_presence_of :title, :category, :expires_at

  has_many :outcomes, -> { order('eth_market_id ASC, created_at ASC') }, class_name: "MarketOutcome", dependent: :destroy, inverse_of: :market

  validates :outcomes, length: { minimum: 2, maximum: 2 } # currently supporting only binary markets

  accepts_nested_attributes_for :outcomes

  scope :published, -> { where('published_at < ?', DateTime.now).where.not(eth_market_id: nil) }
  scope :open, -> { published.where('expires_at > ?', DateTime.now) }
  scope :resolved, -> { published.where('expires_at < ?', DateTime.now) }

  IMMUTABLE_FIELDS = [:title]

  def self.create_from_eth_market_id!(eth_market_id)
    eth_data = Ethereum::PredictionMarketContractService.new.get_market(eth_market_id)

    # invalid market
    return false if eth_data[:outcomes].blank?

    market = Market.new(
      title: eth_data[:title],
      category: "Foo", # no data from category in blockchain
      subcategory: "Bar", # no data from category in blockchain
      eth_market_id: eth_market_id,
      expires_at: eth_data[:expires_at],
      published_at: DateTime.now,
      image_url: 'https://s2.coinmarketcap.com/static/img/coins/200x200/8579.png', # no data from image in blockchain
    )
    eth_data[:outcomes].each do |outcome|
      market.outcomes << MarketOutcome.new(title: outcome[:title], eth_market_id: outcome[:id])
    end

    market.save!
    market
  end

  def eth_data(refresh = false)
    return nil if eth_market_id.blank?

    return @eth_data if @eth_data.present? && !refresh

    Rails.cache.fetch("markets:#{eth_market_id}", expires_in: 24.hours, force: refresh) do
      @eth_data = Ethereum::PredictionMarketContractService.new.get_market(eth_market_id)
    end
  end

  def open?
    !closed?
  end

  def closed?
    return false if eth_data.blank?

    eth_data[:expires_at] < DateTime.now
  end

  def resolved?
    closed? && eth_data[:state] == 'resolved'
  end

  def expires_at
    return self["expires_at"] if eth_data.blank?

    eth_data[:expires_at]
  end

  def state
    return nil if eth_data.blank?

    state = eth_data[:state]

    # market already closed, manually sending closed
    return 'closed' if eth_data[:state] == 'open' && closed?

    state
  end

  def resolved_outcome_id
    return nil if eth_data.blank?

    eth_data[:resolved_outcome_id]
  end

  def liquidity
    return nil if eth_data.blank?

    eth_data[:liquidity]
  end

  def shares
    return nil if eth_data.blank?

    eth_data[:shares]
  end

  def liquidity_price
    prices[:liquidity_price]
  end

  def prices(refresh: false)
    return {} if eth_market_id.blank?

    Rails.cache.fetch("markets:#{eth_market_id}:prices", expires_in: 24.hours, force: refresh) do
      Ethereum::PredictionMarketContractService.new.get_market_prices(eth_market_id)
    end
  end

  def outcome_prices(timeframe, candles: 12, refresh: false)
    return {} if eth_market_id.blank?

    market_prices =
      Rails.cache.fetch("markets:#{eth_market_id}:events:price", expires_in: 24.hours, force: refresh) do
        Ethereum::PredictionMarketContractService.new.get_price_events(eth_market_id)
      end

    market_prices.group_by { |price| price[:outcome_id] }.map do |outcome_id, prices|
      chart_data_service = ChartDataService.new(prices, :price)
      # returning in hash form
      [outcome_id, chart_data_service.chart_data_for(timeframe, candles)]
    end.to_h
  end

  def liquidity_prices(timeframe, candles: 12, refresh: false)
    return [] if eth_market_id.blank?

    liquidity_prices =
      Rails.cache.fetch("markets:#{eth_market_id}:events:liquidity", expires_in: 24.hours, force: refresh) do
        Ethereum::PredictionMarketContractService.new.get_liquidity_events(eth_market_id)
      end

    chart_data_service = ChartDataService.new(liquidity_prices, :price)
    chart_data_service.chart_data_for(timeframe, candles)
  end

  def action_events(address: nil, refresh: false)
    return [] if eth_market_id.blank?

    # TODO: review caching both globally and locally

    market_actions =
      Rails.cache.fetch("markets:#{eth_market_id}:actions", expires_in: 24.hours, force: refresh) do
        Ethereum::PredictionMarketContractService.new.get_action_events(market_id: eth_market_id)
      end

    market_actions.select do |action|
      address.blank? || action[:address].downcase == address.downcase
    end
  end

  def volume
    action_events
      .select { |a| ['buy', 'sell'].include?(a[:action]) }
      .sum { |a| a[:value] }
  end

  def refresh_cache!
    # clearing all cache entries
    $redis_store.keys("markets:#{eth_market_id}*").each { |key| $redis_store.del key }

    # triggering a refresh for all cached ethereum data
    eth_data(true)
    outcome_prices('1h', refresh: true)
    action_events(refresh: true)
    prices(refresh: true)
  end
end
