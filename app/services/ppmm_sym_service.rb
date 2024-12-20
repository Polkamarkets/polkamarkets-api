class PpmmSymService
  attr_accessor :service

  # Initialize the service with an empty markets hash
  def initialize(service)
    @service = service
  end

  # Find a user holding shares for a specific outcome
  def find_user_with_shares(market_id, outcome_id)
    market = service.markets[market_id]
    market[:users].select { |user| (user[:shares][outcome_id] || 0) > 0 }.sample
  end

  # Hybrid Simulation: Random buys and sells
  def hybrid_simulation(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    num_actions.times do
      user_id = rand(0..num_users)
      outcome_id = outcomes.sample
      action_type = [:buy, :sell].sample

      if action_type == :sell
        # Find a user holding shares; if none, fallback to buy
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares
          user_id = user_with_shares[:id]
          percentage_to_sell = rand(10.0..100.0)
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        else
          action_type = :buy
        end
      end

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.00001)
      end
    end
  end

  # Constant Heavy Selling: More buying on one side, followed by heavy selling
  def constant_heavy_selling(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    biased_outcome = outcomes.sample

    # Perform buys with bias
    num_actions.times do
      user_id = rand(0..num_users)
      outcome_id = rand < 0.7 ? biased_outcome : outcomes.sample
      value = rand(10.0..100.0)
      service.buy(user_id, market_id, outcome_id, value, 0.00001)
    end

    # 90% of users sell their positions
    (0..num_users).to_a.sample((num_users * 0.9).to_i).each do |user_id|
      user_with_shares = find_user_with_shares(market_id, biased_outcome)
      if user_with_shares
        user_id = user_with_shares[:id]
        service.sell_shares_percentage(user_id, market_id, biased_outcome, 100.0)
      end
    end
  end

  # Everyone Sells: Hybrid actions followed by everyone selling their positions
  def everyone_sells(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    num_actions.times do
      user_id = rand(0..num_users)
      outcome_id = outcomes.sample
      action_type = [:buy, :sell].sample

      if action_type == :sell
        # Find a user holding shares; if none, fallback to buy
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares
          user_id = user_with_shares[:id]
          percentage_to_sell = rand(10.0..100.0)
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        else
          action_type = :buy
        end
      end

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.00001)
      end
    end

    # Everyone sells their positions
    (0..num_users).each do |user_id|
      outcomes.shuffle.each do |outcome_id|
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares
          user_id = user_with_shares[:id]
          service.sell_shares_percentage(user_id, market_id, outcome_id, 100.0)
        end
      end
    end
  end

  def heavy_buying_simulation(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    biased_outcome = outcomes.sample # The outcome with heavy buying

    num_actions.times do
      user_id = rand(0..num_users)
      action_type = rand < 0.8 ? :buy : :sell # 80% buys, 20% sells
      market = service.markets[market_id]

      # Determine the least likely outcome dynamically
      probabilities = outcomes.map do |outcome_id|
        outcome = market[:outcomes].find { |o| o[:id] == outcome_id }
        service.calculate_probability(market, outcome)
      end
      least_likely_outcome = outcomes[probabilities.index(probabilities.min)]

      # Determine the outcome for the action
      outcome_id = if action_type == :buy
                     rand < 0.8 ? biased_outcome : least_likely_outcome
                   else
                     outcomes.sample
                   end

      if action_type == :sell
        # Find a user holding shares; if none, fallback to buy
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares
          user_id = user_with_shares[:id]
          percentage_to_sell = rand(10.0..50.0)
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        else
          puts "No user with shares of #{outcome_id} found. Fallback to buy."
          action_type = :buy
        end
      end

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.00001)
      end
    end
  end

  def last_minute_whales_simulation(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    regular_users = (0..num_users).to_a
    whale_users = [num_users + 1, num_users + 2] # Add two "whales" with higher IDs

    # Regular users perform normal actions
    (num_actions - 10).times do
      user_id = regular_users.sample
      outcome_id = outcomes.sample
      action_type = [:buy, :sell].sample

      if action_type == :sell
        # Find a user holding shares; if none, fallback to buy
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares
          user_id = user_with_shares[:id]
          percentage_to_sell = rand(10.0..100.0)
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        else
          action_type = :buy
        end
      end

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.00001)
      end
    end

    whale_outcome_id = outcomes.sample

    # Whales buy large positions in the last few actions
    10.times do
      whale_id = whale_users.sample
      outcome_id = whale_outcome_id
      large_value = rand(500.0..1000.0) # Whales make large purchases
      service.buy(whale_id, market_id, outcome_id, large_value, 0.00001)
    end
  end
end
