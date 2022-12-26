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

      # removing blacklisted wallets from leaderboard
      leaderboard.reject! { |user| wallets.include?(user[:user]) }

      rewards = Hash.new(0)

      StatsService::LEADERBOARD_PARAMS.each do |param, specs|
        winners = leaderboard.sort_by { |user| -user[param] }.select { |user| user[param] > 0 }[0..specs[:amount] - 1]
        next if winners.blank?

        winners.each_with_index do |winner, index|
          puts "#{network};#{param};#{index + 1};#{winner[:user]};#{specs[:value]}\n"

          rewards[winner[:user]] += specs[:value]
        end
      end

      puts "\n#{network} Rewards\n"
      rewards.each do |user, reward|
        puts "#{user};#{reward}\n"
      end
    end
  end
end
