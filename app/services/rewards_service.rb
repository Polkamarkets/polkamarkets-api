class RewardsService
  include NetworkHelper, TimeframerHelper


  attr_accessor :actions
  attr_accessor :locks


  def initialize
    @networks = rewards_network_ids.map do |network_id|
      {
        network_id: network_id,
        chain: Rails.application.config_for(:ethereum)[:"rewards_network_#{network_id}"][:reward_contract_chain],
        reward_timeframe: Rails.application.config_for(:ethereum)[:"rewards_network_#{network_id}"][:reward_timeframe]
      }
    end
  end

  def get_rewards(date: Date.today, top: 10)

    rewards = @networks.to_h do |network|

      timeframe = network[:reward_timeframe]

      from = timestamp_from(date.to_time.to_i, timeframe)
      to = timestamp_to(date.to_time.to_i, timeframe)

      from_block = get_block_number_from_timestamp(from, network[:chain])
      to_block = get_block_number_from_timestamp(to, network[:chain]) + 1 # add 1 to include the last block

      @weight_of_each_block = 1.0 / (to_block - from_block)

      @tiers = get_tiers(network[:network_id])

      network_id = network[:network_id]
      actions = network_actions(network_id)
      locks = network_locks(network_id)
      markets_resolved = network_markets_resolved(network_id)

      # concat locks and markets_resolved
      locks.concat(markets_resolved)

      @user_rewards = {}

      # filter actions that are liquidity related
      actions.select! { |action| ['add_liquidity', 'remove_liquidity'].include?(action[:action]) }

      # grouping locks by block_number
      locks_by_block = locks.group_by do |lock|
        lock[:block_number]
      end

      locks_by_block.filter! do |block_number, a|
        block_number > from_block && block_number <= to_block
      end

      locks_by_block = locks_by_block.sort.to_h

      # Init previous_block and lock state
      lock_state = get_locks_by_market({}, locks.select { |lock| lock[:block_number] < from_block })
      previous_block = from_block

      locks_by_block.each do |block_number, _|

        lock_state = get_locks_by_market(lock_state, locks.select { |lock| lock[:block_number] >= previous_block && lock[:block_number] < block_number })

        markets_on_top = get_lock_top(top, lock_state, block_number)

        # compute the rewards between previous_block and block_number
        iterate_liquidity(markets_on_top, actions.select { |action| action[:block_number] < block_number }, previous_block, block_number)

        previous_block = block_number

      end

      # GET TOP MARKETS AT TO_BLOCK.
      lock_state = get_locks_by_market(lock_state, locks.select { |lock| lock[:block_number] >= previous_block && lock[:block_number] < to_block })

      markets_on_top = get_lock_top(top, lock_state, to_block)

      iterate_liquidity(markets_on_top, actions.select { |action| action[:block_number] < to_block }, previous_block, to_block)

      [
        network_id,
        @user_rewards
      ]
    end.to_h

    rewards
  end

  private

  def get_tiers(network_id)
    Bepro::RewardContractService.new(network_id: network_id).tiers_info
  end

  def rewards_network_ids
    @_rewards_network_ids ||= Rails.application.config_for(:ethereum).rewards_network_ids
  end

  def compute_rewards(markets_on_top, liquidity_state, from_block, to_block)
    user_rewards_for_this_block = {}
    total_liquidity_for_this_block = 0

    # iterate markets_on_top and check if the user has liquidity in the market
    markets_on_top.each do |market_id, locked_info|

      liquidity = liquidity_state[market_id]

      next if liquidity.blank?

      # iterate liquidity users of the market
      liquidity[:users].each do |user_address, liquidity|
        # compute rewards
        multiplier = get_locked_multiplier(locked_info[:users][user_address]);
        if user_rewards_for_this_block[user_address].blank?
          user_rewards_for_this_block[user_address] = 0
        end

        user_rewards_for_this_block[user_address] += liquidity * multiplier

        total_liquidity_for_this_block += liquidity * multiplier
      end
    end

    user_rewards_for_this_block.each do |user_address, reward|
      @user_rewards[user_address] = 0 if @user_rewards[user_address].blank?

      @user_rewards[user_address] += reward.to_f / total_liquidity_for_this_block * @weight_of_each_block * (to_block - from_block)
    end

  end

  def get_locked_multiplier(locked_amount)
    locked_amount = 0 if locked_amount.blank?

    @tiers.each do |tier|
      if locked_amount <= tier[:max_amount]
        return tier[:multiplier]
      end
    end
  end

  def iterate_liquidity(markets_on_top, actions, from_block, to_block)

    # grouping actions by block_number
    actions_by_block = actions.group_by do |action|
      action[:block_number]
    end

    actions_by_block.filter! do |block_number, a|
      block_number > from_block && block_number <= to_block
    end

    actions_by_block = actions_by_block.sort.to_h

    # GET LIQUIDITY AT FROM_BLOCK
    liquidity_state = get_liquidity_by_markets(markets_on_top, {}, actions.select { |action| action[:block_number] < from_block })

    previous_block = from_block

    actions_by_block.each do |block_number, a|

      # GET LIQUIDITY AT BLOCK_NUMBER
      liquidity_state = get_liquidity_by_markets(markets_on_top, liquidity_state, actions.select { |action| action[:block_number] >= previous_block && action[:block_number] < block_number })

      compute_rewards(markets_on_top, liquidity_state, previous_block, block_number)

      previous_block = block_number
    end

    # GET LIQUIDITY AT TO_BLOCK
    liquidity_state = get_liquidity_by_markets(markets_on_top, liquidity_state, actions.select { |action| action[:block_number] >= previous_block && action[:block_number] < to_block })

    compute_rewards(markets_on_top, liquidity_state, previous_block, to_block)

  end

  def get_lock_top(n, lock_state, at_block_number)
    # remove from lock state the ones with market_resolved_at_block < at_block_number
    top_entries = lock_state
      .select { |_, value| value[:market_resolved_at_block].nil? || value[:market_resolved_at_block] >= at_block_number }
      .sort_by { |_, value| -value[:lock_amount] }.first(n)
    top_entries.to_h
  end

  def get_liquidity_by_markets(markets_on_top, liquidity, actions)
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

        user_address = action[:address]
        liquidity[market_id][:liquidity_shares] += shares_to_add
        if liquidity[market_id][:users][user_address].blank?
          liquidity[market_id][:users][user_address] = 0
        end
        liquidity[market_id][:users][user_address] += shares_to_add

      end

    end

    liquidity
  end

  def get_locks_by_market(locks, lock_actions)

    lock_actions.each do |action|
      if action[:item_id].present?
        market_id = action[:item_id]
  
        # still no action performed in this market, initializing object
        if locks[market_id].blank?
          locks[market_id] = {
            lock_amount: 0,
            users: {},
            market_resolved_at_block: nil
          }
        end
  
        shares_to_add = 0
        case action[:action]
          when 'lock'
            shares_to_add = action[:lock_amount]
          when 'unlock'
            shares_to_add = -1 * action[:lock_amount]
        end
  
        user_address = action[:user]
        locks[market_id][:lock_amount] += shares_to_add
        if locks[market_id][:users][user_address].blank?
          locks[market_id][:users][user_address] = 0
        end
        locks[market_id][:users][user_address] += shares_to_add
      else
        # it's a market resolved event
        market_id = action[:market_id]

        if locks[market_id].blank?
          locks[market_id] = {
            lock_amount: 0,
            users: {},
            market_resolved_at_block: nil
          }
        end

        locks[market_id][:market_resolved_at_block] = action[:block_number]
      end
    end

    locks
  end

  def get_block_number_from_timestamp(timestamp, chain = 'mainnet')

    block = EtherscanService.new(chain).block_number_by_timestamp(timestamp)
    return block[:blockNumber]
  end

end
