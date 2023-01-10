namespace :group_leaderboards do
  desc "refreshes banner image of all leaderboards"
  task :update_banner_image, [:symbol] => :environment do |task, args|
    GroupLeaderboard.all.each do |group_leaderboard|
      GroupLeaderboardBannerWorker.perform_async(group_leaderboard.id)
    end
  end
end
