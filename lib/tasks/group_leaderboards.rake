namespace :group_leaderboards do
  desc "refreshes banner image of all leaderboards"
  task :update_banner_image, [:symbol] => :environment do |task, args|
    GroupLeaderboard.all.each do |group_leaderboard|
      group_leaderboard.update_banner_image
    end
  end
end
