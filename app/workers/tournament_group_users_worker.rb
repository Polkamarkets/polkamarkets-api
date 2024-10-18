class TournamentGroupUsersWorker
  include Sidekiq::Worker

  def perform(tournament_group_id)
    tournament_group = TournamentGroup.find_by(id: tournament_group_id)
    return if tournament_group.blank? || tournament_group.token.blank? || tournament_group.whitelabel?

    # fetching mint actions and creating user associations
    mint_events = Bepro::Erc20ContractService.new(
      network_id: tournament_group.network_id,
      contract_address: tournament_group.token[:address]
    ).mint_events

    mint_event_addresses = mint_events.map { |event| event[:to] }.uniq
    users = User.where(wallet_address: mint_event_addresses)

    users_not_in_group = users - tournament_group.reload.users

    users_not_in_group.each do |user|
      tournament_group.users << user
    end

    tournament_group.update_counters
  end
end
