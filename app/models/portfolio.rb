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

  # profit/loss from resolved events
  def closed_markets_profit
    value = 0

    # fetching holdings markets
    market_ids = holdings.map { |holding| holding[:market_id] }.uniq

    markets = Market.where(eth_market_id: market_ids).includes(:outcomes)
    # filtering holdings by resolved by markets
    markets = markets.to_a.select { |market| market.resolved? }

    markets.each do |market|
      # TODO: add liquidity shares value
      holding = holdings.find { |holding| holding[:market_id] == market.eth_market_id }

      # calculating holding value
      market.outcomes.each do |outcome|
        if holding[:outcome_shares][outcome.eth_market_id] > 0
          multiplicator = outcome.eth_market_id == market.resolved_outcome_id ? 1 : -1
          value += multiplicator * holding[:outcome_shares][outcome.eth_market_id]
        end
      end
    end

    value
  end

  def open_positions
    holdings.count
  end

  def liquidity_provided
    holdings.sum { |holding| holding[:liquidity_shares] }
  end

  def liquidity_fees_earned
    # TODO
    0
  end

  def holdings_value
    value = 0

    # fetching holdings markets
    market_ids = holdings.map { |holding| holding[:market_id] }.uniq
    markets = Market.where(eth_market_id: market_ids).includes(:outcomes)
    # ignoring resolved by markets
    markets = markets.to_a.reject { |market| market.resolved? }

    markets.each do |market|
      holding = holdings.find { |holding| holding[:market_id] == market.eth_market_id }

      # calculating liquidity value
      if holding[:liquidity_shares] > 0
        value += holding[:liquidity_shares] * market.liquidity_price
      end

      # calculating holding value
      market.outcomes.each do |outcome|
        if holding[:outcome_shares][outcome.eth_market_id] > 0
          value += holding[:outcome_shares][outcome.eth_market_id] * outcome.price
        end
      end
    end

    value
  end

  def holdings_performance
    holdings_chart_24h = holdings_chart_for('24h')
    holdings_chart_24h_value = holdings_chart_24h.first&.fetch(:value) || 0

    return { change: 0, change_percent: 0 } unless holdings_chart_24h_value > 0

    {
      change: holdings_value - holdings_chart_24h_value,
      change_percent: (holdings_value - holdings_chart_24h_value) / holdings_chart_24h_value,
    }
  end

  def holdings_timeline
    return @holdings_timeline if @holdings_timeline.present?

    # seeding holdings array by timestamp
    holdings = {}
    @holdings_timeline = []

    action_events.each do |action|
      # still no action performed in this market, initializing object
      if holdings[action[:market_id]].blank?
        holdings[action[:market_id]] = {
          liquidity_shares: 0,
          outcome_shares: {
            0 => 0,
            1 => 0
          }
        }
      end

      case action[:action]
      when 'buy'
        holdings[action[:market_id]][:outcome_shares][action[:outcome_id]] += action[:shares]
      when 'sell'
        holdings[action[:market_id]][:outcome_shares][action[:outcome_id]] -= action[:shares]
      when 'add_liquidity'
        holdings[action[:market_id]][:liquidity_shares] += action[:shares]
      when 'remove_liquidity'
        holdings[action[:market_id]][:liquidity_shares] -= action[:shares]
      end

      @holdings_timeline.push({
        timestamp: action[:timestamp],
        holdings: holdings.deep_dup,
      })
    end

    @holdings_timeline
  end

  def chart_timeframe
    return @chart_timeframe if @chart_timeframe.present?

    # no actions in portfolio, returning 7d as default
    return '7d' if action_events.blank?

    first_action_timestamp = action_events.map { |a| a[:timestamp] }.min

    timeframe = ChartDataService::TIMEFRAMES.find do |timeframe, duration|
      (DateTime.now - duration).to_i < first_action_timestamp
    end

    @chart_timeframe = timeframe&.first || 'all'
  end

  def holdings_chart(refresh: false)
    expires_at = ChartDataService.next_datetime_for(chart_timeframe)
    # caching chart until next candlestick
    expires_in = expires_at.to_i - DateTime.now.to_i

    portfolio_chart =
      Rails.cache.fetch(
        "portfolios:#{eth_address}:chart:#{chart_timeframe}",
        expires_in: expires_in.seconds,
        force: refresh
      ) do
        # defaulting to [] if no portfolio data
        holdings_chart_for(chart_timeframe) || []
      end

    # changing value of last item for current price
    if portfolio_chart.present?
      portfolio_chart.last[:value] = holdings_value if portfolio_chart.present?
      portfolio_chart.last[:timestamp] = DateTime.now.to_i if portfolio_chart.present?
    else
      portfolio_chart = [
        price_chart = [{
          value: holdings_value,
          timestamp: Time.now.to_i,
          date: Time.now,
        }]
      ]
    end

    portfolio_chart
  end

  def holdings_chart_for(timeframe)
    return [] if action_events.blank?

    # fetching price chart from market ids
    holding_market_ids = action_events.select { |a| ['buy', 'sell'].include?(a[:action]) }.map { |a| a[:market_id] }.uniq
    liquidity_market_ids = action_events
      .select { |a| ['add_liquidity', 'remove_liquidity']
      .include?(a[:action]) }
      .map { |a| a[:market_id] }
      .uniq

    market_charts = holding_market_ids.map do |market_id|
      market = Market.find_by!(eth_market_id: market_id)
      [market_id, market.outcome_prices(timeframe)]
    end.to_h

    liquidity_charts = liquidity_market_ids.map do |market_id|
      market = Market.find_by!(eth_market_id: market_id)
      [market_id, market.liquidity_prices(timeframe)]
    end.to_h

    timestamps = ChartDataService.timestamps_for(timeframe)

    first_action_timestamp = action_events.map { |a| a[:timestamp] }.min
    # filtering timestamps prior to portfolio start date (only leaving first)
    timestamps_to_exclude = timestamps.select { |timestamp| timestamp < first_action_timestamp }[1..-1]
    timestamps.reject! { |timestamp| timestamps_to_exclude&.include?(timestamp) }

    timestamps.reverse.map do |timestamp|
      # calculating holdings value at every chart's timestamp
      value = 0
      holdings_at_timestamp = holdings_at(timestamp)
      if holdings_at_timestamp.present?
        holdings_at_timestamp[:holdings].each do |market_id, holdings|
          # calculating liquidity value
          if holdings[:liquidity_shares] > 0
            price_item = liquidity_charts[market_id].select { |point| point[:timestamp] <= timestamp }&.last
            value += holdings[:liquidity_shares] * (price_item&.fetch(:value) || 0)
          end

          # calculating holdings value
          outcome_ids = [0, 1]
          outcome_ids.each do |outcome_id|
            if holdings[:outcome_shares][outcome_id] > 0
              price_item = market_charts[market_id][outcome_id].select { |point| point[:timestamp] <= timestamp }&.last
              value += holdings[:outcome_shares][outcome_id] * (price_item&.fetch(:value) || 0)
            end
          end
        end
      end

      {
        value: value,
        timestamp: timestamp,
        date: Time.at(timestamp)
      }
    end
  end

  def holdings_at(timestamp)
    holdings_timeline.select { |holding| holding[:timestamp] < timestamp }.max_by { |holding| holding[:timestamp] }
  end

  def refresh_cache!
    # disabling cache delete for now
    # $redis_store.keys("portfolios:#{eth_address}*").each { |key| $redis_store.del key }

    # triggering a refresh for all cached ethereum data
    Cache::PortfolioActionEventsWorker.perform_async(id)
    Cache::PortfolioHoldingsWorker.perform_async(id)
  end
end
