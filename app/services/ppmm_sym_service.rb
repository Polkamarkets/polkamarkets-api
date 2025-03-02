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
  def hybrid_simulation(market_id, num_actions: 1000, num_users: 70, outcomes: [0, 1])
    num_actions.times do
      user_id = rand(0..num_users)
      outcome_id = rand > 0.65 ? outcomes.first : outcomes.last
      action_type = rand > 0.9 ? :sell : :buy

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
        service.buy(user_id, market_id, outcome_id, value, 0.0000000001)
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
      service.buy(user_id, market_id, outcome_id, value, 0.0000000001)
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
        service.buy(user_id, market_id, outcome_id, value, 0.0000000001)
      end
    end

    # Everyone sells their positions
    (0..num_users).each do |user_id|
      outcomes.shuffle.each do |outcome_id|
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares
          user_id = user_with_shares[:id]
          service.sell_shares_percentage(user_id, market_id, outcome_id, 100.0) if outcome_id == 0
        end
      end
    end
  end

  def heavy_buying_simulation(market_id, num_actions: 100, num_users: 700, outcomes: [0, 1])
    biased_outcome = outcomes.sample # The outcome with heavy buying

    num_actions.times do
      user_id = rand(0..num_users)
      action_type = rand < 0.95 ? :buy : :sell # 80% buys, 20% sells
      market = service.markets[market_id]

      # Determine the least likely outcome dynamically
      probabilities = outcomes.map do |outcome_id|
        outcome = market[:outcomes].find { |o| o[:id] == outcome_id }
        service.calculate_probability(market, outcome)
      end
      least_likely_outcome = outcomes[probabilities.index(probabilities.min)]

      # Determine the outcome for the action
      outcome_id = if action_type == :buy
                     rand < 0.95 ? biased_outcome : least_likely_outcome
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
        value = rand(50.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.0000000001)
      end
    end
  end

  def last_minute_whales_simulation(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    regular_users = (0..num_users).to_a
    whale_count = 30
    whale_users = (num_users + 1..num_users + whale_count + 1).to_a # Add two "whales" with higher IDs

    whale_outcome_id = outcomes.sample
    other_outcome_id = outcomes.find { |o| o != whale_outcome_id }

    # performing a buy in whale_outcome_id and other in other_outcome_id at 10% probability
    service.buy(12345, market_id, whale_outcome_id, 1, 0.0000000001)
    service.buy(12346, market_id, other_outcome_id, 0.05, 0.0000000001)
    service.buy(12345, market_id, whale_outcome_id, 1.5, 0.0000000001)

    # Regular users perform normal actions
    (num_actions).times do
      user_id = regular_users.sample
      outcome_id = outcomes.sample
      action_type = rand > 0.9 ? :sell : :buy

      if action_type == :sell
        # Find a user holding shares; if none, fallback to buy
        user_with_shares = find_user_with_shares(market_id, outcome_id)
        if user_with_shares && user_with_shares[:id] != 12345
          user_id = user_with_shares[:id]
          percentage_to_sell = rand(100.0..100.0)
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        else
          action_type = :buy
        end
      end

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.0000000001)
      end
    end

    # Whales buy large positions in the last few actions
    whale_count.times.each do |i|
      whale_id = whale_users[i]
      # outcome_id = whale_outcome_id
      outcome_id = rand > 0.9 ? whale_outcome_id : whale_outcome_id
      large_value = rand(100.0..200.0) # Whales make large purchases
      service.buy(whale_id, market_id, outcome_id, large_value, 0.0000000001)
      # also buying a small position for a shark in the other outcome
      service.buy(whale_id + 1000, market_id, other_outcome_id, 0.01, 0.0000000001)
    end
  end

  def simulate_from_ipfs(ipfs_hash)
    uri = "https://ipfs.io/ipfs/#{ipfs_hash}"
    response = HTTP.get(uri)

    unless response.status.success?
      raise "PpmmSymService #{response.status} :: #{response.body.to_s}"
    end

    actions = JSON.parse(response.body.to_s)

    puts "Simulating #{actions.size} actions from IPFS hash #{ipfs_hash}"

    actions.each do |action|
      next unless ['buy', 'sell'].include?(action['action'])

      user_id = action['address']
      market_id = 0
      outcome_id = action['outcome_id']
      value = action['value']
      price = action['price']

      if action['action'] == 'buy'
        service.buy(user_id, market_id, outcome_id, value, 1e-50, pm_action: action)
      else
        # always selling 100% for simplicity
        service.sell_shares_percentage(user_id, market_id, outcome_id, 100, pm_action: action)
      end
    end
  end
end
