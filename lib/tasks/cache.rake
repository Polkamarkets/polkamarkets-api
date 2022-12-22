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
    leaderboard_1d = StatsService.new.get_leaderboard(timeframe: '1d', refresh: true)
    Rails.cache.write("api:leaderboard:1d", leaderboard_1d, expires_in: 24.hours)
    leaderboard_1w = StatsService.new.get_leaderboard(timeframe: '1w', refresh: true)
    Rails.cache.write("api:leaderboard:1w", leaderboard_1w, expires_in: 24.hours)
    leaderboard_1m = StatsService.new.get_leaderboard(timeframe: '1m', refresh: true)
    Rails.cache.write("api:leaderboard:1m", leaderboard_1m, expires_in: 24.hours)
    leaderboard_at = StatsService.new.get_leaderboard(timeframe: 'at', refresh: true)
    Rails.cache.write("api:leaderboard:at", leaderboard_at, expires_in: 24.hours)
  end

  desc "refreshes cache of network actions"
  task :refresh_actions, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.map do |network_id|
      actions = Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      Rails.cache.write("api:actions:#{network_id}", actions, expires_in: 24.hours)

      bonds = Bepro::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
      Rails.cache.write("api:bonds:#{network_id}", bonds, expires_in: 24.hours)
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
