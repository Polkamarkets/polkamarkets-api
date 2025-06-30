class TournamentRewardsWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(tournament_id)
    tournament = Tournament.find(tournament_id)
    return if tournament.blank?

    TournamentRewardsService.new(tournament_id).distribute_rewards
  end
end
