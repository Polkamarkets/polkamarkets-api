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
  end

  desc "refreshes cache of network actions"
  task :refresh_actions, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.map do |network_id|
      puts network_id
      actions = Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      Rails.cache.write("api:actions:#{network_id}", actions, expires_in: 24.hours)

      bonds = Bepro::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
      Rails.cache.write("api:bonds:#{network_id}", bonds, expires_in: 24.hours)
    end
  end
end
