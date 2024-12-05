class PpmmService
  attr_accessor :markets

  # Initialize the service with an empty markets hash
  def initialize
    @markets = {}
  end

  # Create a new market
  def create_market(market_id, outcomes, k: 1.0, w: 0.5, fee: 0.02)
    @markets[market_id] = {
      k: k,
      w: w,
      fee: fee,
      outcomes: outcomes.map { |id| { id: id, amount: 0, shares: 0 } },
      users: []
    }
  end

  # Buy shares
  def buy(user_id, market_id, outcome_id, value, min_shares_to_buy)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)
    user = find_or_create_user(market, user_id)

    # Calculate shares to buy
    shares_to_buy = calculate_buy_amount(market_id, outcome_id, value)
    raise "Minimum shares not met" if shares_to_buy < min_shares_to_buy

    # Update market, outcome, and user
    outcome[:amount] += value
    outcome[:shares] += shares_to_buy
    user[:amount][outcome_id] = user[:amount].fetch(outcome_id, 0) + value
    user[:total_buy_amount][outcome_id] = user[:total_buy_amount].fetch(outcome_id, 0) + value
    user[:shares][outcome_id] = user[:shares].fetch(outcome_id, 0) + shares_to_buy
    user[:total_bought_shares][outcome_id] = user[:total_bought_shares].fetch(outcome_id, 0) + shares_to_buy

    shares_to_buy
  end

  # Sell shares
  def sell(user_id, market_id, outcome_id, value, max_shares_to_sell)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)
    user = find_user(market, user_id)

    # Calculate proceeds
    shares_to_sell = calculate_sell_amount(market_id, outcome_id, value)
    raise "Exceeds maximum shares to sell" if shares_to_sell > max_shares_to_sell

    # Ensure user has sufficient shares
    raise "User has insufficient shares" if user[:shares][outcome_id].to_f < shares_to_sell

    # Update market, outcome, and user
    outcome[:amount] -= value
    outcome[:shares] -= shares_to_sell
    user[:amount][outcome_id] -= value
    user[:shares][outcome_id] -= shares_to_sell

    shares_to_sell
  end

  def sell_shares(user_id, market_id, outcome_id, shares_to_sell)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)
    user = find_user(market, user_id)

    # Calculate proceeds
    proceeds = calculate_sell_value(market_id, outcome_id, shares_to_sell)

    # Ensure user has sufficient shares
    raise "User has insufficient shares" if user[:shares][outcome_id].to_f < shares_to_sell

    # Update market, outcome, and user
    outcome[:amount] -= proceeds
    outcome[:shares] -= shares_to_sell
    user[:amount][outcome_id] -= proceeds
    user[:shares][outcome_id] -= shares_to_sell

    proceeds
  end

  def sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)
    user = find_user(market, user_id)

    # Ensure the percentage is valid
    raise "Percentage must be between 0 and 100" if percentage_to_sell <= 0 || percentage_to_sell > 100

    # Calculate the number of shares to sell based on the percentage
    shares_to_sell = (user[:shares][outcome_id] || 0) * (percentage_to_sell / 100.0)

    # Ensure user has sufficient shares
    raise "User has insufficient shares" if shares_to_sell > (user[:shares][outcome_id] || 0)

    # Use the sell_shares method to handle the selling process
    sell_shares(user_id, market_id, outcome_id, shares_to_sell)
  end

  # Calculate buy amount (number of shares for a given value)
  def calculate_buy_amount(market_id, outcome_id, value)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)

    # Calculate weighted probability
    probability_before = calculate_probability(market, outcome)
    probability_after = calculate_probability_after_buy(market, outcome, value)
    weighted_probability = calculate_weighted_probability(probability_before, probability_after, market[:w])

    # Calculate shares
    weight = calculate_weight(weighted_probability, market[:k])
    value / weight
  end

  # Calculate sell amount (proceeds for a given number of shares sold)
  def calculate_sell_amount(market_id, outcome_id, value)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)

    # Calculate weighted probability
    probability_before = calculate_probability(market, outcome)
    probability_after = calculate_probability_after_sell(market, outcome, value)
    weighted_probability = calculate_weighted_probability(probability_before, probability_after, market[:w])

    # Calculate shares
    weight = calculate_weight(weighted_probability, market[:k])
    value / weight
  end

  def calculate_sell_value(market_id, outcome_id, shares, tolerance: 1e-6, max_iterations: 100)
    market = @markets[market_id]
    outcome = find_outcome(market, outcome_id)

    # Initial range for bisection
    low = 0
    high = outcome[:amount]  # Assuming the pool amount as an upper bound
    iterations = 0

    while iterations < max_iterations
      mid = (low + high) / 2.0
      calculated_shares = calculate_sell_amount(market_id, outcome_id, mid)

      # Check if we've matched the desired number of shares within the tolerance
      if (calculated_shares - shares).abs <= tolerance
        return mid
      end

      # Adjust the range based on whether we need more or fewer shares
      if calculated_shares > shares
        high = mid
      else
        low = mid
      end

      iterations += 1
    end

    # If we reach here, return the midpoint as the best estimate
    mid
  end

  # Calculate the probability of an outcome based on current pool amounts
  def calculate_probability(market, outcome)
    total_amount = market[:outcomes].sum { |o| o[:amount] }
    return 1.0 / market[:outcomes].length if total_amount.zero?

    outcome[:amount] / total_amount
  end

  # Calculate the probability after buying
  def calculate_probability_after_buy(market, outcome, value)
    total_amount = market[:outcomes].sum { |o| o[:amount] } + value
    (outcome[:amount] + value) / total_amount
  end

  # Calculate the probability after selling
  def calculate_probability_after_sell(market, outcome, value)
    total_amount = market[:outcomes].sum { |o| o[:amount] } - value
    (outcome[:amount] - value) / total_amount
  end

  # Calculate the tailored weight for probabilities
  def calculate_weight(probability, k)
    0.5 + (probability - 0.5) / (1 + k * (probability - 0.5)**2)
  end

  # Calculate the weighted probability (blend of before and after)
  def calculate_weighted_probability(probability_before, probability_after, w)
    (w * probability_before) + ((1 - w) * probability_after)
  end

  # Find an outcome by ID
  def find_outcome(market, outcome_id)
    market[:outcomes].find { |outcome| outcome[:id] == outcome_id } ||
      raise("Outcome not found")
  end

  # Find or create a user
  def find_or_create_user(market, user_id)
    user = market[:users].find { |u| u[:id] == user_id }
    unless user
      user = { id: user_id, amount: {}, shares: {}, total_buy_amount: {}, total_bought_shares: {} }
      market[:users] << user
    end
    user
  end

  # Find an existing user
  def find_user(market, user_id)
    market[:users].find { |u| u[:id] == user_id } || raise("User not found")
  end

  # Pretty print breakdown for all users
  def pretty_print_breakdown(market_id)
    market = @markets[market_id]

    market[:outcomes].each do |outcome|
      outcome_id = outcome[:id]
      total_amount = outcome[:amount] || 0
      total_shares = outcome[:shares] || 0

      puts "Breakdown for Outcome #{outcome_id}"
      # Header with aligned column widths
      puts format("%-8s | %-8s | %-8s | %-8s | %-8s | %-14s | %-8s | %-8s",
                  "User ID", "Amount", "Shares", "Share %", "Payout", "Total Received", "Profit", "PnL")
      puts "-" * 80

      # Calculate the total relative amount shares pool for this outcome
      total_relative_amount_share = market[:users].sum do |user|
        user_shares = user[:shares].fetch(outcome_id, 0)
        total_bought_shares = user[:total_bought_shares].fetch(outcome_id, 0)
        total_buy_amount = user[:total_buy_amount].fetch(outcome_id, 0)

        if total_bought_shares > 0
          (user_shares / total_bought_shares.to_f) * total_buy_amount
        else
          0
        end
      end

      market[:users].each do |user|
        # Safely retrieve user's amount and shares, defaulting to 0 if nil
        user_amount = user[:amount].fetch(outcome_id, 0)
        user_shares = user[:shares].fetch(outcome_id, 0)

        # Get user's total buy stats for this outcome
        total_buy_amount = user[:total_buy_amount].fetch(outcome_id, 0)
        total_bought_shares = user[:total_bought_shares].fetch(outcome_id, 0)

        # Skip users who have no contributions or shares
        next if total_buy_amount.zero? && total_bought_shares.zero?

        # Calculate share % of pool
        share_percentage = total_shares > 0 ? (user_shares / total_shares.to_f * 100) : 0

        # Calculate payout from other pools
        pool_sum = market[:outcomes].sum { |o| o[:id] == outcome_id ? o[:amount] : 0 }
        other_pools_sum = market[:outcomes].sum { |o| o[:id] != outcome_id ? o[:amount] : 0 }
        payout_from_pool = (share_percentage / 100) * other_pools_sum

        # Calculate user's relative amount share for this outcome
        relative_amount_share = if total_bought_shares > 0
                                  (user_shares / total_bought_shares.to_f) * total_buy_amount
                                else
                                  0
                                end

        # Calculate user's relative amount percentage of the entire relative amount shares pool
        relative_amount_percentage = total_relative_amount_share > 0 ?
                                      (relative_amount_share / total_relative_amount_share.to_f) * 100 :
                                      0

        # Total received if outcome wins
        total_received = payout_from_pool + (relative_amount_percentage / 100) * pool_sum

        # Profit and PnL
        profit = total_received - user_amount
        pnl = total_buy_amount.zero? ? 0 : (profit / total_buy_amount.to_f) * 100

        # Print user breakdown with aligned formatting
        puts format("%-8d | %-8.2f | %-8.2f | %-8.2f | %-8.2f | %-14.2f | %-8.2f | %-8.2f",
                    user[:id], user_amount, user_shares, share_percentage, payout_from_pool,
                    total_received, profit, pnl)
      end

      puts "\n"
    end
  end
end
