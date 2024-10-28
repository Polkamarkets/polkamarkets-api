class TournamentRewardWorker
  include Sidekiq::Worker

  def perform(tournament_id)

    # Find tournaments that have not been computed
    tournament = Tournament.find_by(id: tournament_id)

    return if tournament.blank? || tournament.computed_claims?

    # if tournament is not resolved, return
    return unless tournament.resolved?

    # compute leaderboard
    leaderboard = LeaderboardService.new.get_tournament_leaderboard(tournament.network_id, tournament.id, refresh: true)

    leaderboard.each_with_index do |user_data, index|
      rank = index + 1
      reward = tournament.rewards.find { |reward| rank >= reward['from'] && rank <= reward['to'] }

      claim_service = ClaimService.new

      token_address = claim_service.get_wallet_address_preferred_token(tournament.network_id, user_data[:user], reward['token_addresses'])

      claim_service.create_claim(tournament.network_id, user_data[:user], reward['value'], token_address, 'tournament', { tournament_id: tournament.id })
    end

    tournament.update!(computed_claims: true)
  end
end
