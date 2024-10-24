namespace :tournaments do
  desc "computes the tournaments rewards for all tournament groups"
  task :compute_rewards, [:symbol] => :environment do |task, args|
    Tournament.all.each do |tournament|
      TournamentRewardWorker.perform_async(tournament.id)
    end
  end
end
