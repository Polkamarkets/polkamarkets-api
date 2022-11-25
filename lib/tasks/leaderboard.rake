namespace :leaderboard do
  desc "fetches and prints leaderboard winners"
  task :winners, [] => :environment do |task, args|
    timeframe = args.to_a.present? ? args.to_a[0] : '1w'
    wallets = args.to_a[1..-1].to_a

    timestamp = timeframe == 'at' ? Time.now.to_i : (Time.now - 1.send(StatsService::TIMEFRAMES[timeframe])).to_i

    networks_leaderboard = StatsService.new.get_leaderboard(timeframe: timeframe, timestamp: timestamp)
    networks_leaderboard.each do |network_id, leaderboard|
      network = Rails.application.config_for(:networks).find { |name, id| id == network_id }
      network = network ? network.first.to_s.capitalize : 'Unknown'

      puts "#{network}\n"

      # removing blacklisted wallets from leaderboard
      leaderboard.reject! { |user| wallets.include?(user[:user]) }

      StatsService::LEADERBOARD_PARAMS.each do |param, count|
        winners = leaderboard.sort_by { |user| -user[param] }.select { |user| user[param] > 0 }[0..count - 1]
        next if winners.blank?

        puts param
        winners.each_with_index do |winner, index|
          puts "#{index + 1} - `#{winner[:user]}`"
        end
        puts "\n"
      end
    end
  end

  task :round_winners, [] => :environment do |task, args|
    start_timestamp = args.to_a[0].to_i
    end_timestamp = args.to_a[1].to_i

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      network = Rails.application.config_for(:networks).find { |name, id| id == network_id.to_i }
      network = network ? network.first.to_s.capitalize : 'Unknown'

      puts "#{network}\n"

      markets = Market
        .includes(:outcomes)
        .where(network_id: network_id, expires_at: Time.at(start_timestamp)..Time.at(end_timestamp)).all

      actions = Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      end

      # removing invalid actions - users with same prediction in same market and different outcomes
      filtered_actions = actions.reject do |action|
        actions.any? do |action2|
          action[:address] == action2[:address] && action[:market_id] == action2[:market_id] && action[:outcome_id] != action2[:outcome_id]
        end
      end

      # removing actions from markets that were not created in the timeframe
      filtered_actions.reject! { |action| markets.none? { |market| market.eth_market_id == action[:market_id] } }

      # only accounting for buy/sell actions
      filtered_actions.select! { |action| action[:action] == 'buy' || action[:action] == 'sell' }

      winning_outcome_actions = filtered_actions.select do |action|
        market = markets.find { |market| market.eth_market_id == action[:market_id] }
        market.resolved_outcome_id == action[:outcome_id]
      end

      # getting winning action at lower price (value / shares)
      winning_action = winning_outcome_actions.sort_by { |action| action[:value].to_f / action[:shares].to_f }.first
      winning_action_market = markets.find { |market| market.eth_market_id == winning_action&.dig(:market_id) }

      if winning_action_market
        puts "The Underdog: #{winning_action[:address]} - Bought \"#{winning_action_market.outcomes.find { |outcome| outcome.eth_market_id == winning_action[:outcome_id] }.title}\" at \"#{winning_action_market.title}\""
      end

      # fetching all erc20 balances from cache and returning highest one
      erc20_balances_keys = $redis_store.keys('api:erc20_balances:*')
      erc20_balances_keys.sort_by! do |key|
        Rails.cache.read(key)
      end

      # getting highest erc20 balance (excluding last one, which is the token manager)
      highest_erc20_balance_address = erc20_balances_keys[-2].split(':').last

      puts "Top Manager: #{highest_erc20_balance_address} - #{Rails.cache.read(erc20_balances_keys[-2])} $IFL"

      # filtering markets where lowest outcome price is the winner
      lowest_outcome_markets = markets.select do |market|
        market.outcomes.sort_by { |outcome| outcome.price }.first.eth_market_id == market.resolved_outcome_id
      end

      winning_actions_on_lowest_outcome_markets = winning_outcome_actions.select do |action|
        lowest_outcome_markets.any? { |market| market.eth_market_id == action[:market_id] }
      end

      # getting users with most winning actions on lowest outcome markets
      winning_actions_on_lowest_outcome_markets_by_user =
        winning_actions_on_lowest_outcome_markets
          .group_by { |action| action[:address] }
          .map { |address, actions| [address, [actions.map { |a| a[:market_id] }.uniq.count, actions.sum { |a| a[:shares] }]] }
          .sort_by { |address, (count, shares)| [-count, -shares] }

      puts "Wild Baller: #{winning_actions_on_lowest_outcome_markets_by_user.first.first} - #{winning_actions_on_lowest_outcome_markets_by_user.first.last.first} markets, #{winning_actions_on_lowest_outcome_markets_by_user.first.last.last} shares"

      # filtering markets where highest outcome price is the winner
      highest_outcome_markets = markets.select do |market|
        market.outcomes.sort_by { |outcome| outcome.price }.last.eth_market_id == market.resolved_outcome_id
      end

      winning_actions_on_highest_outcome_markets = winning_outcome_actions.select do |action|
        highest_outcome_markets.any? { |market| market.eth_market_id == action[:market_id] }
      end

      # getting users with most winning actions on highest outcome markets
      winning_actions_on_highest_outcome_markets_by_user =
        winning_actions_on_highest_outcome_markets
          .group_by { |action| action[:address] }
          .map { |address, actions| [address, [actions.map { |a| a[:market_id] }.uniq.count, actions.sum { |a| a[:shares] }]] }
          .sort_by { |address, (count, shares)| [-count, -shares] }

      puts "Bus Parker: #{winning_actions_on_highest_outcome_markets_by_user.first.first} - #{winning_actions_on_highest_outcome_markets_by_user.first.last.first} markets, #{winning_actions_on_highest_outcome_markets_by_user.first.last.last} shares"
    end
  end
end
