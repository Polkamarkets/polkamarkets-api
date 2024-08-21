class Portfolio < ApplicationRecord
  validates_presence_of :eth_address
  validates_uniqueness_of :eth_address, scope: :network_id

  before_validation :normalize_eth_address

  validate :eth_address_validation

  def self.empty_portfolio(address, network_id)
    {
      address: address,
      network_id: network_id.to_i,
      holdings_value: 0,
      holdings_performance: {
        change: -0,
        change_percent: -0
      },
      holdings_chart: [],
      open_positions: 0,
      won_positions: 0,
      total_positions: 0,
      closed_markets_profit: 0,
      liquidity_provided: 0,
      liquidity_fees_earned: 0,
      first_position_at: nil
    }
  end

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
      Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:actions", force: refresh) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events(address: eth_address)
      end
  end

  def burn_action_events(refresh: false)
    return [] unless Rails.application.config_for(:ethereum).fantasy_enabled

    return @burn_actions if @burn_actions.present? && !refresh

    @burn_actions ||=
      Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:burn_actions", force: refresh) do
        Bepro::Erc20ContractService.new(network_id: network_id).burn_events(from: eth_address)
      end
  end

  def burn_total
    return 0 unless Rails.application.config_for(:ethereum).fantasy_enabled

    burn_action_events.sum { |event| event[:value] }
  end

  def feed_events(refresh: false)
    Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:feed", force: refresh) do
      FeedService.new(address: eth_address, network_id: network_id).feed_actions
    end
  end

  def portfolio_market_ids
    action_events.map { |event| event[:market_id] }.uniq.sort.reverse
  end

  def holdings
    return [] if holdings_timeline.empty?

    holdings_timeline.last[:holdings].map do |market_id, holding|
      {
        market_id: market_id,
        address: eth_address,
        outcome_shares: holding[:outcome_shares],
        liquidity_shares: holding[:liquidity_shares],
      }
    end
  end

  def closed_markets_winnings(filter_by_market_ids: nil, refresh: false)
    value = 0
    count = 0

    winnings_by_market =
      Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:closed_markets_winnings", expires_in: 24.hours, force: refresh) do
        winnings_by_market = {
          winnings: Hash.new(0),
          accuracy: Hash.new(false)
        }

        # fetching holdings markets
        market_ids = holdings.map { |holding| holding[:market_id] }.uniq

        markets = Market.where(eth_market_id: market_ids, network_id: network_id).includes(:outcomes)
        # filtering holdings by resolved by markets
        markets = markets.to_a.select { |market| market.resolved? }

        markets.each do |market|
          holding = holdings.find { |holding| holding[:market_id] == market.eth_market_id }

          market.outcomes.each do |outcome|
            next unless holding[:outcome_shares][outcome.eth_market_id] > 1e0

            if outcome.eth_market_id == market.resolved_outcome_id
              winnings_by_market[:winnings][market.eth_market_id] += holding[:outcome_shares][market.resolved_outcome_id] * market.token_rate
              winnings_by_market[:accuracy][market.eth_market_id] = true
            elsif market.voided
              winnings_by_market[:winnings][market.eth_market_id] += holding[:outcome_shares][outcome.eth_market_id] * market.token_rate * outcome.price
            else
              # lost position
              winnings_by_market[:accuracy][market.eth_market_id] = false
            end
          end
        end

        winnings_by_market
      end

    # filtering by market ids if provided
    winnings_by_market[:winnings].select! { |market_id, value| filter_by_market_ids.include?(market_id) } if !filter_by_market_ids.nil?
    winnings_by_market[:accuracy].select! { |market_id, value| filter_by_market_ids.include?(market_id) } if !filter_by_market_ids.nil?

    voided_market_ids = (Market.all_voided_market_ids[network_id] || []) & winnings_by_market[:winnings].keys

    {
      value: winnings_by_market[:winnings].values.sum,
      # filtering out winnings from voided markets for count
      count: winnings_by_market[:winnings].keys.count { |market_id| !voided_market_ids.include?(market_id) },
      accuracy: winnings_by_market[:accuracy].values.count(true).to_f / winnings_by_market[:accuracy].values.count
    }
  end

  # profit/loss from resolved events
  def closed_markets_profit
    value = 0

    # fetching holdings markets
    market_ids = holdings.map { |holding| holding[:market_id] }.uniq

    markets = Market.where(eth_market_id: market_ids, network_id: network_id).includes(:outcomes)
    # filtering holdings by resolved by markets
    markets = markets.to_a.select { |market| market.resolved? }

    markets.each do |market|
      # TODO: add liquidity shares value
      holding = holdings.find { |holding| holding[:market_id] == market.eth_market_id }

      # calculating holding value
      market.outcomes.each do |outcome|
        if holding[:outcome_shares][outcome.eth_market_id] > 1e0
          multiplicator = outcome.eth_market_id == market.resolved_outcome_id ? 1 : -1
          value += multiplicator * holding[:outcome_shares][outcome.eth_market_id] * market.token_rate
        end
      end
    end

    value
  end

  def first_position_at
    action_events.select { |event| event[:action] == 'buy' }.min_by { |event| event[:timestamp] }&.dig(:timestamp)
  end

  def open_positions(filter_by_market_ids: nil, refresh: false)
    holdings_by_market = holdings_value_by_market(refresh: refresh)

    # filtering by market ids if provided
    holdings_value_by_market.select! { |market_id, value| filter_by_market_ids.include?(market_id) } if !filter_by_market_ids.nil?

    holdings_value_by_market.values.count
  end

  def won_positions
    closed_markets_winnings[:count]
  end

  def accuracy
    closed_markets_winnings[:accuracy]
  end

  def total_positions
    action_events.select { |event| event[:action] == 'buy' }.count
  end

  def liquidity_provided
    market_ids = holdings
      .select { |holding| holding[:liquidity_shares] > 0 }
      .map { |holding| holding[:market_id] }
      .uniq
    markets = Market.where(eth_market_id: market_ids, network_id: network_id)


    holdings.sum do |holding|
      market = markets.find { |market| market.eth_market_id == holding[:market_id] }

      next 0 unless market.present?

      holding[:liquidity_shares] * market.liquidity_price * market.token_rate
    end
  end

  def liquidity_fees_earned(refresh: false)
    return @liquidity_fees_earned if @liquidity_fees_earned.present? && !refresh

    @liquidity_fees_earned ||=
      Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:liquidity_fees", force: refresh) do
        events = Bepro::PredictionMarketContractService.new(network_id: network_id).get_user_liquidity_fees_earned(eth_address)

        market_ids = events.map { |event| event[:market_id] }.uniq
        markets = Market.where(eth_market_id: market_ids, network_id: network_id)

        events.sum do |event|
          market = markets.find { |market| market.eth_market_id == event[:market_id] }

          return 0 unless market.present?

          event[:value] * market.token_rate
        end
      end
  end

  def holdings_value_by_market(refresh: false)
    return @holdings_value_by_market if @holdings_value_by_market.present? && !refresh

    @holdings_value_by_market =
      Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:holdings_by_market", expires_in: 24.hours, force: refresh) do
        holdings_value_by_market = Hash.new(0)

        # fetching holdings markets
        market_ids = holdings.map { |holding| holding[:market_id] }.uniq

        markets = Market.where(eth_market_id: market_ids, network_id: network_id).includes(:outcomes)
        # ignoring resolved markets
        markets = markets.to_a.reject { |market| market.resolved? }

        markets.each do |market|
          holding = holdings.find { |holding| holding[:market_id] == market.eth_market_id }

          # calculating liquidity value
          if holding[:liquidity_shares] > 0
            # holdings_value_by_market[market.eth_market_id] += holding[:liquidity_shares] * market.liquidity_price * market.token_rate
          end

          # calculating holding value
          market.outcomes.each do |outcome|
            if holding[:outcome_shares][outcome.eth_market_id] > 1e0
              holdings_value_by_market[market.eth_market_id] += holding[:outcome_shares][outcome.eth_market_id] * outcome.price * market.token_rate
            end
          end
        end

        holdings_value_by_market
      end
  end

  def holdings_value(filter_by_market_ids: nil, refresh: false)
    value = 0

    holdings_by_market = holdings_value_by_market(refresh: refresh)

    # filtering by market ids if provided
    holdings_by_market.select! { |market_id, value| filter_by_market_ids.include?(market_id) } if !filter_by_market_ids.nil?

    holdings_by_market.values.sum
  end

  def holdings_cost(filter_by_market_ids: nil, refresh: false)
    value = 0

    holdings_cost_by_market =
      Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:holdings_cost", expires_in: 24.hours, force: refresh) do
        holdings_cost_by_market = Hash.new(0)

        # fetching holdings markets
        market_ids = holdings.map { |holding| holding[:market_id] }.uniq

        markets = Market.where(eth_market_id: market_ids, network_id: network_id).includes(:outcomes)
        # ignoring resolved markets
        markets = markets.to_a.reject { |market| market.resolved? }

        markets.each do |market|
          holding = holdings.find { |holding| holding[:market_id] == market.eth_market_id }

          # calculating holding value
          market.outcomes.each do |outcome|
            if holding[:outcome_shares][outcome.eth_market_id] > 1e0
              # fetching average cost
              outcome_buy_events = action_events.select do |event|
                event[:market_id] == market.eth_market_id && event[:outcome_id] == outcome.eth_market_id && event[:action] == 'buy'
              end

              outcome_buy_price = outcome_buy_events.sum { |event| event[:value] } / outcome_buy_events.sum { |event| event[:shares] }

              holdings_cost_by_market[market.eth_market_id] += holding[:outcome_shares][outcome.eth_market_id] * outcome_buy_price * market.token_rate
            end
          end
        end

        holdings_cost_by_market
      end

    # filtering by market ids if provided
    holdings_cost_by_market.select! { |market_id, value| filter_by_market_ids.include?(market_id) } if !filter_by_market_ids.nil?

    holdings_cost_by_market.values.sum
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

    markets = Market
      .where(eth_market_id: action_events.map { |action| action[:market_id] }.uniq, network_id: network_id)
      .includes(:outcomes)
      .all

    action_events.each do |action|
      market = markets.find { |market| market.eth_market_id == action[:market_id] }

      # still no action performed in this market, initializing object
      if holdings[action[:market_id]].blank?
        holdings[action[:market_id]] = {
          liquidity_shares: 0,
          outcome_shares: market.outcomes.map { |outcome| [outcome.eth_market_id, 0] }.to_h,
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
        block_number: action[:block_number],
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
        "portfolios:network_#{network_id}:#{eth_address}:chart:#{chart_timeframe}",
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
    holdings_market_ids = action_events.select { |a| ['buy', 'sell'].include?(a[:action]) }.map { |a| a[:market_id] }.uniq
    liquidity_market_ids = action_events
      .select { |a| ['add_liquidity', 'remove_liquidity']
      .include?(a[:action]) }
      .map { |a| a[:market_id] }
      .uniq

    holdings_markets = Market.where(eth_market_id: holdings_market_ids, network_id: network_id).all
    liquidity_markets = Market.where(eth_market_id: liquidity_market_ids, network_id: network_id).all

    market_charts = holdings_market_ids.map do |market_id|
      market = holdings_markets.find { |market| market.eth_market_id == market_id }
      [market_id, market.outcome_prices(timeframe)]
    end.to_h

    liquidity_charts = liquidity_market_ids.map do |market_id|
      market = liquidity_markets.find { |market| market.eth_market_id == market_id }
      [market_id, market.liquidity_prices(timeframe)]
    end.to_h


    first_action_timestamp = action_events.map { |a| a[:timestamp] }.min
    # filtering timestamps prior to portfolio start date (only leaving first)
    timestamps = ChartDataService.timestamps_for(timeframe, first_action_timestamp)
    timestamps_to_exclude = timestamps.select { |timestamp| timestamp < first_action_timestamp }[1..-1]
    timestamps.reject! { |timestamp| timestamps_to_exclude&.include?(timestamp) }

    timestamps.reverse.map do |timestamp|
      # calculating holdings value at every chart's timestamp
      value = 0
      holdings_at_timestamp = holdings_at(timestamp)
      if holdings_at_timestamp.present?
        holdings_at_timestamp[:holdings].each do |market_id, holdings|
          market = holdings_markets.find { |market| market.eth_market_id == market_id } ||
            liquidity_markets.find { |market| market.eth_market_id == market_id }

          # ignoring resolved markets
          next if market.resolved_at > 0 && market.resolved_at < timestamp

          # calculating liquidity value
          if holdings[:liquidity_shares] > 1e0 && !market.resolved?
            price_item = liquidity_charts[market_id].select { |point| point[:timestamp] <= timestamp }&.last
            value += holdings[:liquidity_shares] * (price_item&.fetch(:value) || 0) * market.token_rate_at(timestamp)
          end

          # calculating holdings value
          outcome_ids = [0, 1]
          outcome_ids.each do |outcome_id|
            if holdings[:outcome_shares][outcome_id] > 1e0
              price_item = market_charts[market_id][outcome_id].select { |point| point[:timestamp] <= timestamp }&.last
              value += holdings[:outcome_shares][outcome_id] * (price_item&.fetch(:value) || 0) * market.token_rate_at(timestamp)
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

  def erc20_balance
    Rails.cache.fetch("portfolios:network_#{network_id}:#{eth_address}:erc20_balance", force: refresh) do
      Bepro::Erc20ContractService.new(network_id: network_id).balance_of(eth_address)
    end
  end

  def refresh_cache!(queue: 'default')
    # disabling cache delete for now
    # $redis_store.keys("portfolios:#{eth_address}*").each { |key| $redis_store.del key }

    # triggering a refresh for all cached ethereum data
    Cache::PortfolioActionEventsWorker.set(queue: queue).perform_async(id)
    unless Rails.application.config_for(:ethereum).fantasy_enabled
      Cache::PortfolioLiquidityFeesWorker.set(queue: queue).perform_async(id)
    end
    Cache::PortfolioFeedWorker.set(queue: queue).perform_async(id)
  end
end
