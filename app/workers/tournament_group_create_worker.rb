class TournamentGroupCreateWorker
  include Sidekiq::Worker

  def perform(tournament_group_id, everyone_can_create_markets = false)
    tournament_group = TournamentGroup.find_by(id: tournament_group_id)
    return if tournament_group.blank? || tournament_group.token_address.present?

    controller_contract_service =
      Bepro::PredictionMarketControllerContractService.new(network_id: tournament_group.network_id)

    token_amount_to_claim = Rails.application.config_for(:ethereum).token_amount_to_claim > 0 ?
      Rails.application.config_for(:ethereum).token_amount_to_claim : 1000
    token_to_answer = Rails.application.config_for(:ethereum).dig(:"network_#{tournament_group.network_id}", :erc20_contract_address)

    created_land = controller_contract_service.create_land(
      tournament_group.title,
      tournament_group.symbol,
      token_amount_to_claim,
      token_to_answer
    )

    token_address = created_land['events']['LandCreated'][0]['returnValues']['token']

    # adding admins on-chain
    tournament_group.admins.each do |user|
      controller_contract_service.add_admin_to_land(token_address, user)
    end

    tournament_group.token_address = token_address
    tournament_group.token_controller_address = controller_contract_service.contract_address

    if everyone_can_create_markets
      controller_contract_service.set_land_everyone_can_create_markets(token_address, true)
    end

    tournament_group.save!
    # refreshing admins
    tournament_group.admins(refresh: true)

    tournament_group
  end
end
