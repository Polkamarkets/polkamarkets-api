class MarketResolutionService
  def initialize(market_resolution_id)
    @market_resolution = MarketResolution.find(market_resolution_id)
  end

  def resolve_market
    market = @market_resolution.market
    market_template = @market_resolution.market_template
    market_schedule = @market_resolution.market_schedule

    # Check if market is eligible for resolution
    return unless should_resolve?(market)

    case market_template.template_type
    when 'fear_and_greed'
      fear_and_greed_resolution
    when 'binance_price'
      binance_price_resolution
    else
      raise "Unsupported template type: #{market_template.template_type}"
    end
  end

  private

  def should_resolve?(market)
    return false unless market.published?
    return false unless market.open?
    return false if @market_resolution.resolved?

    true
  end

  def fear_and_greed_resolution
    market = @market_resolution.market
    resolution_variables = @market_resolution.resolution_variables

    # Validate required variables
    target_index = resolution_variables['target']
    raise "Target index is required" if target_index.blank?

    resolution_date = resolution_variables['resolution_date']
    raise "Resolution date is required" if resolution_date.blank?

    resolves_at = DateTime.parse(resolution_date)

    # Check if it's time to resolve
    return unless DateTime.now >= resolves_at

    # Get Fear & Greed index for the resolution date
    current_index = get_fear_and_greed_index_at_date(resolves_at)
    return unless current_index

    # Determine winning outcome
    outcome_id = determine_fear_and_greed_outcome(market, target_index.to_i, current_index)
    return unless outcome_id

    # Resolve the market
    resolve_market_on_chain(market, outcome_id)
  end

  def binance_price_resolution
    market = @market_resolution.market
    resolution_variables = @market_resolution.resolution_variables
    schedule_template_variables = @market_resolution.market_schedule.template_variables

    # Validate required variables
    target_price = resolution_variables['target']
    resolution_date = resolution_variables['resolution_date']
    symbol = schedule_template_variables['symbol']

    raise "Symbol is required" if symbol.blank?
    raise "Target price is required" if target_price.blank?
    raise "Resolution date is required" if resolution_date.blank?

    resolves_at = DateTime.parse(resolution_date)

    # Check if it's time to resolve
    return unless DateTime.now >= resolves_at

    # Get Binance price for the resolution date
    current_price = get_binance_price_at_date(symbol, resolves_at)
    return unless current_price

    # Determine winning outcome
    outcome_id = determine_binance_price_outcome(market, target_price.to_f, current_price)
    return unless outcome_id

    # Resolve the market
    resolve_market_on_chain(market, outcome_id)
  end

  def get_fear_and_greed_index_at_date(target_date)
    begin
      # Get historical data to find the index at the target date
      # We'll get more data to ensure we have the target date
      index_history = FearAndGreedService.get_index_history(30)

      # Find the closest index to the target date
      target_timestamp = target_date.to_i
      closest_index = index_history.min_by do |item|
        (item[:timestamp] - target_timestamp).abs
      end

      return closest_index[:value] if closest_index
    rescue => e
      Rails.logger.error "Failed to get Fear & Greed index for date #{target_date}: #{e.message}"
      Sentry.capture_exception(e) if defined?(Sentry)
    end

    nil
  end

  def get_binance_price_at_date(symbol, target_date)
    begin
      # Convert target date to milliseconds for Binance API
      target_timestamp = target_date.to_i * 1000

      # Get price data around the target date
      # We'll get 1-hour candles for the day around the target time
      start_time = target_date.beginning_of_day
      end_time = target_date.end_of_day

      price_events = BinanceApiService.get_price_events(
        symbol,
        '1h',
        24,
        start_time,
        end_time
      )

      # Find the closest price to the target time
      target_timestamp = target_date.to_i * 1000
      closest_price = price_events.min_by do |event|
        (event[:close_time] - target_timestamp).abs
      end

      return closest_price[:close] if closest_price

    rescue => e
      Rails.logger.error "Failed to get Binance price for #{symbol} at #{target_date}: #{e.message}"
      Sentry.capture_exception(e) if defined?(Sentry)
    end

    nil
  end

  def determine_fear_and_greed_outcome(market, target_index, current_index)
    outcomes = market.outcomes.order(:eth_market_id)

    raise "Market #{market.id} has #{outcomes.count} outcomes, expected 2" if outcomes.count != 2

    # Binary market: first outcome is "Yes" (above target), second is "No" (below target)
    current_index >= target_index ? outcomes.first.eth_market_id : outcomes.second.eth_market_id
  end

  def determine_binance_price_outcome(market, target_price, current_price)
    outcomes = market.outcomes.order(:eth_market_id)

    raise "Market #{market.id} has #{outcomes.count} outcomes, expected 2" if outcomes.count != 2

    # Binary market: first outcome is "Yes" (above target), second is "No" (below target)
    current_price > target_price ? outcomes.first.eth_market_id : outcomes.second.eth_market_id
  end

  def resolve_market_on_chain(market, outcome_id)
    begin
      # Resolve the market on-chain
      prediction_market_contract_service = Bepro::PredictionMarketContractService.new(network_id: market.network_id)

      prediction_market_contract_service.admin_resolve_market(
        market.eth_market_id,
        outcome_id
      )

      market.refresh_cache!

      # Mark the resolution as completed
      @market_resolution.update!(resolved: true)
    rescue => e
      raise e
    end
  end
end
