class TournamentGroupCreateWorker
  include Sidekiq::Worker

  def perform(tournament_group_id, everyone_can_create_markets = false)
    tournament_group = TournamentGroup.find_by(id: tournament_group_id)
    return if tournament_group.blank? || tournament_group.token_address.present?

    controller_contract_service =
      Bepro::PredictionMarketControllerContractService.new(network_id: tournament_group.network_id)

    created_land = controller_contract_service.create_land(tournament_group.title, tournament_group.symbol)

    token_address = created_land['events']['LandCreated'][0]['returnValues']['token']

    tournament_group.token_address = token_address
    tournament_group.token_controller_address = controller_contract_service.contract_address

    if everyone_can_create_markets
      controller_contract_service.set_land_everyone_can_create_markets(token_address, true)
    end

    # adding admins on-chain
    tournament_group.admins.each do |user|
      controller_contract_service.add_admin_to_land(token_address, user)
    end

    tournament_group.save!
    # refreshing admins
    tournament_group.admins(refresh: true)

    tournament_group
  end
end