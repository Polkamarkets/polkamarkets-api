class StatsService
  attr_accessor :networks

  def initialize
    # ethereum networks - markets are monitored within the api
    ethereum_networks = network_ids.map do |network_id|
      {
        network_id: network_id,
        bepro_pm: Bepro::PredictionMarketContractService.new(network_id: network_id),
        bepro_realitio: Bepro::RealitioErc20ContractService.new(network_id: network_id)
      }
    end

    # stats networks - only for stats, markets are not monitored within the api
    stats_networks = stats_network_ids.map do |network_id|
      {
        network_id: network_id,
        bepro_pm: Bepro::PredictionMarketContractService.new(
          contract_address: Rails.application.config_for(:ethereum)["stats_network_#{network_id}"]['prediction_market_contract_address'],
          api_url: Rails.application.config_for(:ethereum)["stats_network_#{network_id}"]['bepro_api_url']
        ),
        bepro_realitio: Bepro::RealitioErc20ContractService.new(
          contract_address: Rails.application.config_for(:ethereum)["stats_network_#{network_id}"]['realitio_contract_address'],
          api_url: Rails.application.config_for(:ethereum)["stats_network_#{network_id}"]['bepro_api_url']
        )
      }
    end

    @networks = ethereum_networks + stats_networks
  end

  def get_stats(from: nil, to: nil)
    # TODO: volume chart
    # TODO: TVL chart
    networks.map do |network|
      network_id = network[:network_id]
      actions = network[:bepro_pm].get_action_events
      bonds = network[:bepro_realitio].get_bond_events

      # filtering by timestamps, if provided
      actions = actions.select! do |action|
        (!from || action[:timestamp] >= from) &&
          (!to || action[:timestamp] <= to)
      end

      bonds = bonds.select! do |bond|
        (!from || bond[:timestamp] >= from) &&
          (!to || bond[:timestamp] <= to)
      end

      markets_created = network[:bepro_pm].get_market_count
      volume = actions.select { |v| ['buy', 'sell'].include?(v[:action]) }
      bonds_volume = bonds.sum { |bond| bond[:value] }
      volume_movr = volume.sum { |v| v[:value] }
      fee = network[:bepro_pm].get_fee
      fees_movr = volume.sum { |v| v[:value] } * fee
      users = actions.map { |a| a[:address] }.uniq.count

      [
        network_id,
        {
          markets_created: markets_created,
          bond_volume: bonds_volume,
          bond_volume_eur: bonds_volume * rates[:polkamarkets],
          volume: volume_movr,
          volume_eur: volume_movr * rate(network_id),
          fees: fees_movr,
          fees_eur: fees_movr * rate(network_id),
          users: users,
          transactions: actions.count
        }
      ]
    end.to_h
  end

  def rate(network_id)
    token = TokenRatesService::NETWORK_TOKENS[network_id.to_i]

    return 0 if token.blank?

    rates[token.to_sym]
  end

  def rates
    @_rates ||= TokenRatesService.new.get_rates(
      TokenRatesService::NETWORK_TOKENS.map { |_n, token| token } + ['polkamarkets'],
      'eur'
    )
  end

  private

  def network_ids
    @_network_ids ||= Rails.application.config_for(:ethereum).network_ids
  end

  def stats_network_ids
    @_stats_network_ids ||= Rails.application.config_for(:ethereum).stats_network_ids
  end
end
