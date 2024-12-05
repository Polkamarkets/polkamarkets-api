class PpmmSymService
  attr_accessor :service

  # Initialize the service with an empty markets hash
  def initialize(service)
    @service = service
  end

  # Hybrid Simulation: Random buys and sells
  def hybrid_simulation(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    num_actions.times do
      user_id = rand(0..num_users)
      outcome_id = outcomes.sample
      action_type = [:buy, :sell].sample

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.00001)
      elsif action_type == :sell
        percentage_to_sell = rand(10.0..100.0)
        begin
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        rescue => e
          # Ignore if the user cannot sell due to insufficient shares
        end
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
      begin
        service.sell_shares_percentage(user_id, market_id, biased_outcome, 100.0)
      rescue => e
        # Ignore if the user cannot sell
      end
    end
  end

  # Everyone Sells: Hybrid actions followed by everyone selling their positions
  def everyone_sells(market_id, num_actions: 100, num_users: 70, outcomes: [0, 1])
    num_actions.times do
      user_id = rand(0..num_users)
      outcome_id = outcomes.sample
      action_type = [:buy, :sell].sample

      if action_type == :buy
        value = rand(10.0..100.0)
        service.buy(user_id, market_id, outcome_id, value, 0.00001)
      elsif action_type == :sell
        percentage_to_sell = rand(10.0..100.0)
        begin
          service.sell_shares_percentage(user_id, market_id, outcome_id, percentage_to_sell)
        rescue => e
          # Ignore if the user cannot sell
        end
      end
    end

    # Everyone sells their positions
    (0..num_users).each do |user_id|
      outcomes.each do |outcome_id|
        begin
          service.sell_shares_percentage(user_id, market_id, outcome_id, 100.0)
        rescue => e
          # Ignore if the user cannot sell
        end
      end
    end
  end
end
