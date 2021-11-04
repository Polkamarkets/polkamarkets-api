namespace :portfolios do
  desc "refreshes eth cache of portfolios"
  task :refresh_cache, [:symbol] => :environment do |task, args|
    Portfolio.all.each { |p| p.refresh_cache! }
  end
end
