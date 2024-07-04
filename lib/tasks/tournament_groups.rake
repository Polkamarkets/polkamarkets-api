namespace :tournament_groups do
  desc "refreshes users counter for all tournament groups"
  task :refresh_users, [:symbol] => :environment do |task, args|
    TournamentGroup.all.each do |tournament_group|
      TournamentGroupUsersWorker.perform_async(tournament_group.id)
    end
  end
end
