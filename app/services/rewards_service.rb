class RewardsService
  attr_accessor :actions
  attr_accessor :locks


  def initialize
  end

  def compute_rewards(refresh: false, date: Date.today)
    from, to = get_timestamps(date)

    from_block = get_block_number_from_timestamp(from)
    to_block = get_block_number_from_timestamp(to)

    # Get all actions

    # Get all locks

    # Compute the initial state for all markets at time from_block (liquidity and locks)

    # Compute the rewards at that time

    # when there's an action on a block (liquidity or lock) compute the rewards at that time

    # repeat until to_block
  end

  def timeframe_blocks(timeframe)

  end

  def block_rewards(block_number)

  end

  private

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
