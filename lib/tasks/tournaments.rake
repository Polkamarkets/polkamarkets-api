namespace :tournaments do
  desc "checks template-scheduled tournaments and creates them"
  task :check_template_scheduled_tournaments, [:symbol] => :environment do |task, args|
    TournamentSchedule.all.each do |tournament_schedule|
      next unless tournament_schedule.active?
      next unless tournament_schedule.next_run < DateTime.now

      tournament_template = tournament_schedule.tournament_template
      raise "Schedule has no template" if tournament_template.blank?

      begin
        # creating tournament
        tournament = Tournament.create_draft_from_template!(
          tournament_template.id,
          tournament_schedule.id
        )

        # creating markets
        tournament_schedule.market_schedules.each do |market_schedule|
          market = Market.create_draft_from_template!(
            market_schedule.market_template.id,
            market_schedule.id
          )
          market.tournaments << tournament
          # scheduling market for creation
          market.update(scheduled_at: DateTime.now) if market_schedule.publish_market_enabled?
        end

        tournament_schedule.update(last_run_at: DateTime.now)
      rescue => e
        puts "Error creating tournament from template: #{e.message}"
        # TODO: handle error
      end
    end
  end

  desc "distributes rewards for eligible tournaments"
  task :distribute_rewards, [:tournament_id] => :environment do |task, args|
    tournaments = Tournament.where(auto_distribute_rewards: true).each do |tournament|
      next unless tournament.resolved?
      next if tournament.rewards_distributed?

      TournamentRewardsWorker.perform_async(tournament.id)
    end
  end
end
