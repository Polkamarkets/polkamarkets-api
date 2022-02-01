class StatsService
  attr_accessor :actions, :bonds

  def initialize
    @actions = network_ids.map do |network_id|
      [
        network_id,
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      ]
    end.to_h

    @bonds = network_ids.map do |network_id|
      [
        network_id,
        Bepro::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
      ]
    end.to_h
  end

  def get_stats
    # TODO: volume chart
    # TODO: TVL chart
    network_ids.map do |network_id|

      volume = actions[network_id].select { |v| ['buy', 'sell'].include?(v[:action]) }
      bonds_volume = bonds[network_id].sum { |bond| bond[:value] }
      volume_movr = volume.sum { |v| v[:value] }
      fee = Bepro::PredictionMarketContractService.new(network_id: network_id).get_fee
      fees_movr = volume.sum { |v| v[:value] } * fee

      [
        network_id,
        {
          markets_created: Market.where(network_id: network_id).published.count,
          bond_volume: bonds_volume,
          bond_volume_eur: bonds_volume * rates[:polkamarkets],
          volume: volume_movr,
          volume_eur: volume_movr * rate(network_id),
          fees: fees_movr,
          fees_eur: fees_movr * rate(network_id)
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
end
