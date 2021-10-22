class LeaderboardService
  attr_accessor :actions

  def initialize
    @actions = Bepro::PredictionMarketContractService.new.get_action_events()
  end

  def leaderboard(from_timestamp, to_timestamp)
    timeframe_actions = actions.select { |event| event[:timestamp].between?(from_timestamp, to_timestamp) }
    timeframe_leaderboard = timeframe_actions
      .group_by { |event| event[:address] }
      .map do |address, address_actions|
        {
          address: address,
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
          volume: address_actions.select { |v| ['buy', 'sell', 'add_liquidity', 'remove_liquidity'].include?(v[:action]) }.sum { |v| v[:value] }
        }
      end

    timeframe_leaderboard.sort_by { |user| -user[:volume] }
  end
end
