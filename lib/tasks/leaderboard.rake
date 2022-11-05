namespace :leaderboard do
  desc "fetches and prints leaderboard winners"
  task :winners, [] => :environment do |task, args|
    timeframe = args.to_a.present? ? args.to_a[0] : '1w'
    wallets = args.to_a[1..-1].to_a

    timestamp = timeframe == 'at' ? Time.now.to_i : (Time.now - 2.send(StatsService::TIMEFRAMES[timeframe])).to_i

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
end
