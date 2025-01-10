class TournamentGroupUsersWorker
  include Sidekiq::Worker

  def perform(tournament_group_id)
    tournament_group = TournamentGroup.find_by(id: tournament_group_id)
    return if tournament_group.blank? || tournament_group.token.blank? || tournament_group.whitelabel?

    # fetching minimum block number from the last 12 hours
    from_block = Activity.where(network_id: tournament_group.network_id).where("timestamp > ?", DateTime.now - 12.hours).minimum(:block_number)
    # fallback to latest activity - range
    from_block ||= Activity.max_block_number_by_network_id(tournament_group.network_id) - (
      Rails.application.config_for(:ethereum).dig(:"network_#{tournament_group.network_id}", :block_range) || 1000
    )

    # fetching mint actions and creating user associations
    mint_events = Bepro::Erc20ContractService.new(
      network_id: tournament_group.network_id,
      contract_address: tournament_group.token[:address],
    ).mint_events(from_block: from_block)

    mint_event_addresses = mint_events.map { |event| event[:to] }.uniq
    users = User.where(wallet_address: mint_event_addresses).includes(:tournament_groups)

    users.each do |user|
      user.tournament_groups << tournament_group unless user.tournament_groups.include?(tournament_group)
    end

    tournament_group.update_counters
  end
end
