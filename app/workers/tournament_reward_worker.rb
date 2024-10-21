class TournamentRewardWorker
  include Sidekiq::Worker

  def perform()

    # Find tournaments that have not been computed
    tournaments = Tournament.where(computed_claims: false)

    tournaments.each do |tournament|
      # if tournament is not resolved, skip
      next unless tournament.resolved?

      # compute leaderboard
      leaderboard = LeaderboardService.new.get_tournament_leaderboard(tournament.network_id, tournament.id, refresh: true)

      leaderboard.each_with_index do |user_data, index|
        rank = index + 1
        reward = tournament.rewards.find { |reward| rank >= reward['from'] && rank <= reward['to'] }

        ClaimService.new.create_claim(tournament.network_id, user_data[:user], reward['value'], 'tournament', { tournament_id: tournament.id })
      end

      tournament.update!(computed_claims: true)
    end
  end
end
