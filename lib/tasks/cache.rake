namespace :cache do
  desc "refreshes cache of medium articles"
  task :refresh_articles, [:symbol] => :environment do |task, args|
    articles = MediumService.new.get_latest_articles
    Rails.cache.write("api:articles", articles, expires_in: 24.hours)
  end

  desc "refreshes cache of protocol stats"
  task :refresh_stats, [:symbol] => :environment do |task, args|
    stats = StatsService.new.get_stats
    Rails.cache.write("api:stats", stats, expires_in: 24.hours)

    # updating time-based stats for all timeframes
    stats_1d = StatsService.new.get_stats_by_timeframe(timeframe: '1d', refresh: true)
    Rails.cache.write("api:stats:1d", stats_1d, expires_in: 24.hours)
    stats_1w = StatsService.new.get_stats_by_timeframe(timeframe: '1w', refresh: true)
    Rails.cache.write("api:stats:1w", stats_1w, expires_in: 24.hours)
    stats_1m = StatsService.new.get_stats_by_timeframe(timeframe: '1m', refresh: true)
    Rails.cache.write("api:stats:1m", stats_1m, expires_in: 24.hours)
    stats_at = StatsService.new.get_stats_by_timeframe(timeframe: 'at', refresh: true)
    Rails.cache.write("api:stats:at", stats_at, expires_in: 24.hours)

    # updating time-based leaderboards for all timeframes
    StatsService.new.get_leaderboard(timeframe: '1d', refresh: true)
    StatsService.new.get_leaderboard(timeframe: '1w', refresh: true)
    StatsService.new.get_leaderboard(timeframe: '1m', refresh: true)
    StatsService.new.get_leaderboard(timeframe: 'at', refresh: true)

    # updating time-based leaderboards for all tournaments
    Tournament.all.each do |tournament|
      StatsService.new.get_leaderboard(timeframe: '1d', refresh: true, tournament_id: tournament.id)
      StatsService.new.get_leaderboard(timeframe: '1w', refresh: true, tournament_id: tournament.id)
      StatsService.new.get_leaderboard(timeframe: '1m', refresh: true, tournament_id: tournament.id)
      StatsService.new.get_leaderboard(timeframe: 'at', refresh: true, tournament_id: tournament.id)
    end
  end

  desc "refreshes cache of network actions"
  task :refresh_actions, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.map do |network_id|
      actions = Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      Rails.cache.write("api:actions:#{network_id}", actions, expires_in: 24.hours)

      bonds = Bepro::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
      Rails.cache.write("api:bonds:#{network_id}", bonds, expires_in: 24.hours)

      markets_resolved = Bepro::PredictionMarketContractService.new(network_id: network_id).get_market_resolved_events
      Rails.cache.write("api:markets_resolved:#{network_id}", markets_resolved, expires_in: 24.hours)

      if Rails.application.config_for(:ethereum).fantasy_enabled
        burn_events = Bepro::Erc20ContractService.new(network_id: network_id).burn_events
        Rails.cache.write("api:burn_actions:#{network_id}", burn_events, expires_in: 24.hours)

        mint_events = Bepro::Erc20ContractService.new(network_id: network_id).mint_events
        Rails.cache.write("api:mint_actions:#{network_id}", mint_events, expires_in: 24.hours)
      end

      # fetching users from last 24 hours and creating a Portfolio entry, in case it doesn't exist
      addresses = actions
        .select { |action| action[:timestamp] > 24. hours.ago.to_i }
        .map { |action| action[:address] } +
        bonds.select { |bond| bond[:timestamp] > 24. hours.ago.to_i }
        .map { |bond| bond[:user] }

      missing_addresses = addresses.uniq.map(&:downcase) - Portfolio.where(network_id: network_id).pluck(:eth_address)

      missing_addresses.uniq.each do |address|
        Portfolio.find_or_create_by(eth_address: address.downcase, network_id: network_id)
      end
    end
  end

  desc "refreshes cache of erc20 balances"
  task :refresh_erc20_balances, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.map do |network_id|
      actions = Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      end

      addresses = actions.map { |action| action[:address] }.uniq
      addresses.each do |address|
        balance = Bepro::Erc20ContractService.new(network_id: network_id).balance_of(address)
        Rails.cache.write("api:erc20_balances:#{network_id}:#{address}", balance, expires_in: 24.hours)
      end
    end
  end
end
