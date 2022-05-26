class LeaderboardService
  include NetworkHelper

  attr_accessor :actions

  def initialize
    @actions = network_ids.map do |network_id|
      [
        network_id,
        network_actions(network_id)
      ]
    end.to_h

    # @actions = network_ids.map do |network_id|
    #   network_actions = Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
    #   network_actions.map { |action| action.merge({ network_id: network_id }) }
    # end.flatten
  end

  def leaderboard(from_timestamp, to_timestamp)
    network_leaderboard = network_ids.map do |network_id|
      timeframe_actions = actions[network_id].select { |event| event[:timestamp].between?(from_timestamp, to_timestamp) }
      timeframe_leaderboard = timeframe_actions
        .group_by { |event| event[:address] }
        .map do |address, address_actions|
          volume = address_actions.select { |v| ['buy', 'sell', 'add_liquidity', 'remove_liquidity'].include?(v[:action]) }.sum { |v| v[:value] }

          {
            address: address,
            network_id: network_id.to_i,
            buy_count: address_actions.select { |v| v[:action] == 'buy' }.count,
            buy_total: address_actions.select { |v| v[:action] == 'buy' }.sum { |v| v[:value] },
            sell_count: address_actions.select { |v| v[:action] == 'sell' }.count,
            sell_total: address_actions.select { |v| v[:action] == 'sell' }.sum { |v| v[:value] },
            add_liquidity_count: address_actions.select { |v| v[:action] == 'add_liquidity' }.count,
            add_liquidity_total: address_actions.select { |v| v[:action] == 'add_liquidity' }.sum { |v| v[:value] },
            remove_liquidity_count: address_actions.select { |v| v[:action] == 'remove_liquidity' }.count,
            remove_liquidity_total: address_actions.select { |v| v[:action] == 'remove_liquidity' }.sum { |v| v[:value] },
            claim_winnings_count: address_actions.select { |v| v[:action] == 'claim_winnings' }.count,
            claim_winnings_total: address_actions.select { |v| v[:action] == 'claim_winnings' }.sum { |v| v[:value] },
            volume: volume,
            volume_eur: volume * rate(network_id),
          }
        end

      timeframe_leaderboard
    end

    network_leaderboard.flatten.sort_by { |user| -user[:volume_eur] }
  end

  private

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

  def network_ids
    @_network_ids ||= Rails.application.config_for(:ethereum).network_ids
  end
end
