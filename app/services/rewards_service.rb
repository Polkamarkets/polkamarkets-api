class RewardsService
  include NetworkHelper


  attr_accessor :actions
  attr_accessor :locks


  def initialize
  end

  def compute_rewards(refresh: false, date: Date.today)
    from, to = get_timestamps(date)

    from_block = get_block_number_from_timestamp(from)
    to_block = get_block_number_from_timestamp(to)

    @weight_of_each_block = 1 / (to_block - from_block)

    rewards = networks.to_h do |network|
      network_id = network[:network_id]
      actions = network_actions(network_id)
      locks = network_locks(network_id)

      @user_rewards = {}

      # filter actions that are liquidity related
      actions.select! { |action| ['add_liquidity', 'remove_liquidity'].include?(v[:action]) }


      # grouping locks by block_number
      locks_by_block = locks.group_by do |lock|
        lock[:block_number]
      end

      # GET TOP MARKETS AT FROM_BLOCK
      lock_state = get_locks_by_market({}, locks.select { |lock| lock[:block_number] < from_block })

      markets_on_top = get_lock_top(10, lock_state_before_from)

      previous_block = from_block

      locks_by_block.each do |block_number, locks|
        # compute the rewards between previous_block and block_number
        iterate_liquidity(markets_on_top, actions.select { |action| action[:block_number] <= block_number }, previous_block, block_number)

        # GET TOP MARKETS AT BLOCK_NUMBER
        lock_state = get_locks_by_market(lock_state, locks.select { |lock| lock[:block_number] >= previous_block && lock[:block_number] < block_number })

        markets_on_top = get_lock_top(10, lock_state)

        previous_block = block_number

      end

      # GET TOP MARKETS AT TO_BLOCK
      lock_state = get_locks_by_market(lock_state, locks.select { |lock| lock[:block_number] >= previous_block && lock[:block_number] < to_block })

      markets_on_top = get_lock_top(10, lock_state)

      iterate_liquidity(markets_on_top, actions.select { |action| action[:block_number] <= to_block }, previous_block, to_block)

      [
        network_id,
        @user_rewards
      ]
    end.to_h

    rewards
  end

  private

  def get_liquidity_by_market(markets_on_top, liquidity, actions)
    # Iterate markets on top, filter the actions by market_id and compute the liquidity
    markets_on_top.each do |market_id, lock_amount|

      actions.select { |action| action[:market_id] == market_id }.each do |action|

        # still no action performed in this market, initializing object
        if liquidity[market_id].blank?
          liquidity[market_id] = {
            liquidity_shares: 0,
            users: {}
          }
        end

        shares_to_add = 0
        case action[:action]
          when 'add_liquidity'
            shares_to_add = action[:shares]
          when 'remove_liquidity'
            shares_to_add = -1 * action[:shares]
        end

        user_id = action[:address]
        liquidity[market_id][:liquidity_shares] += shares_to_add
        if liquidity[market_id][:users][user_id].blank?
          liquidity[market_id][:users][user_id] = 0
        end
        liquidity[market_id][:users][user_id] += shares_to_add

      end

    end

    liquidity
  end

  def compute_rewards(markets_on_top, liquidity_state, from_block, to_block)
    # TODO: compute rewards
  end

  def iterate_liquidity(markets_on_top, actions, from_block, to_block)

    # grouping actions by block_number
    actions_by_block = actions.group_by do |action|
      action[:block_number]
    end

    # GET LIQUIDITY AT FROM_BLOCK
    liquidity_state = get_liquidity_by_markets(markets_on_top, {}, actions.select { |action| action[:block_number] < from_block })

    previous_block = from_block

    actions.each do |block_number, action|

      compute_rewards(markets_on_top, liquidity_state, previous_block, block_number)

      # GET LIQUIDITY AT BLOCK_NUMBER
      liquidity_state = get_liquidity_by_markets(markets_on_top, liquidity_state, actions.select { |action| action[:block_number] >= previous_block && action[:block_number] < block_number })

      previous_block = block_number
    end

    # GET LIQUIDITY AT TO_BLOCK
    liquidity_state = get_liquidity_by_markets(markets_on_top, liquidity_state, actions.select { |action| action[:block_number] >= previous_block && action[:block_number] < to_block })

    compute_rewards(markets_on_top, liquidity_state, previous_block, to_block)

  end

  def get_lock_top(n, lock_state)
    top_entries = lock_state.sort_by { |_, amount_locked| -amount_locked }.first(n)
    top_entries.to_h
  end

  def get_locks_by_market(locks, lock_actions)

    lock_actions.each do |action|
      market_id = action[:item_id]

      # still no action performed in this market, initializing object
      if locks[market_id].blank?
        locks[market_id] = 0
      end

      case action[:action]
      when 'lock'
        locks[market_id] += action[:lock_amount]
      when 'unlock'
        locks[market_id] -= action[:lock_amount]
      end
    end

    locks
  end

  def get_timestamps(date)
    # weekly timeframe starts on Fridays due to the rewarding system

    # Find the previous Friday
    previous_friday = date.prev_day(date.wday > 5 ? date.wday - 5 : date.wday + 2)

    # Set the time to midnight
    previous_friday_midnight = previous_friday.to_datetime.midnight

    # Convert to Unix timestamp
    to = previous_friday_midnight.to_i


    # Find the Friday before the previous Friday
    friday_before_previous = previous_friday.prev_day(7)

    # Set the time to midnight
    friday_before_previous_midnight = friday_before_previous.to_datetime.midnight

    # Convert to Unix timestamp
    from = friday_before_previous_midnight.to_i

    return from, to
  end

  def get_block_number_from_timestamp(timestamp)

    block = EtherscanService.new('blockscout').block_number_by_timestamp(timestamp)

    return block['blockNumber']
  end

end
