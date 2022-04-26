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
end
