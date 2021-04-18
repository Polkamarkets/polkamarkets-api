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

  def resolved_earnings
    # profit/loss from resolved events
    # TODO
    123
  end

  def open_positions
    holdings.count
  end

  def liquidity_provided
    # TODO: use liquidity shares price
    holdings.sum { |holding| holding[:liquidity_shares] }
  end

  def liquidity_fees_earned
    # TODO
    0
  end

  def holdings_value
    value = 0

    holdings.each do |holding|
      market_id = holding[:market_id]

      # calculating liquidity value
      if holding[:liquidity_shares] > 0
        # TODO: use liquidity share price (currently assuming at 1)
        value += holding[:liquidity_shares]
      end

      # calculating holding value
      outcome_ids = [0, 1]
      outcome_ids.each do |outcome_id|
        if holding[:outcome_shares][outcome_id] > 0
          outcome = MarketOutcome.includes(:market).find_by!(eth_market_id: outcome_id, markets: { eth_market_id: market_id })
          value += holding[:outcome_shares][outcome_id] * outcome.price
        end
      end
    end

    value
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
        holdings: holdings.clone,
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

    @chart_timeframe = timeframe.first
  end

  def holdings_chart
    expires_at = ChartDataService.next_datetime_for(chart_timeframe)
    # caching chart until next candlestick
    expires_in = expires_at.to_i - DateTime.now.to_i

    portfolio_chart =
      Rails.cache.fetch(
        "portfolios:#{eth_address}:chart:#{chart_timeframe}",
        expires_in: expires_in.seconds
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

    liquidity_charts = holding_market_ids.map do |market_id|
      market = Market.find_by!(eth_market_id: market_id)
      [market_id, market.liquidity_prices(timeframe)]
    end.to_h

    timestamps = ChartDataService.timestamps_for(timeframe)

    first_action_timestamp = action_events.map { |a| a[:timestamp] }.min
    # filtering timestamps prior to portfolio start date (only leaving first)
    timestamps_to_exclude = timestamps.select { |timestamp| timestamp < first_action_timestamp }[1..-1]
    timestamps.reject! { |timestamp| timestamps_to_exclude.include?(timestamp) }

    timestamps.reverse.map do |timestamp|
      # calculating holdings value at every chart's timestamp
      value = 0
      holdings_at_timestamp = holdings_at(timestamp)
      if holdings_at_timestamp.present?
        holdings_at_timestamp[:holdings].each do |market_id, holdings|
          # calculating liquidity value
          if holdings[:liquidity_shares] > 0
            # TODO: use liquidity share price (currently assuming at 1)
            value += holdings[:liquidity_shares]
          end

          # calculating holdings value
          outcome_ids = [0, 1]
          outcome_ids.each do |outcome_id|
            if holdings[:outcome_shares][outcome_id] > 0
              price = market_charts[market_id][outcome_id].find { |point| point[:timestamp] == timestamp }[:value]
              value += holdings[:outcome_shares][outcome_id] * price
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
    # triggering a refresh for all cached ethereum data
    holdings(refresh: true)
    action_events(refresh: true)
  end
end
