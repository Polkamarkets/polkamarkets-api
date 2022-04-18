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

    stats_daily = StatsService.new.get_stats_daily
    Rails.cache.write("api:stats_daily", stats_daily, expires_in: 24.hours)
  end
end
