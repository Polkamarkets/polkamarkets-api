namespace :ens do
  desc "refresh ens domains from all addresses"
  task :refresh_domains, [:symbol] => :environment do |task, args|
    leaderboard_at = StatsService.new.get_leaderboard(timeframe: 'at', refresh: true)
    addresses = leaderboard_at.values.flatten.map { |v| v[:user] }.uniq

    addresses.each do |address|
      puts "going for #{address}"
      EnsService.new.get_ens_domain(address: address, refresh: true)
    end
  end
end
