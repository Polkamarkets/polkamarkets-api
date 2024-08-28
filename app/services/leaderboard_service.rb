class LeaderboardService
  def calculate_market_leaderboard(network_id, market_id, refresh: false)
    market = Market.find_by(eth_market_id: market_id, network_id: network_id)
    return {} if market.blank?

    actions = market.action_events
    users = {}

    if Rails.cache.exist?("market_leaderboard:#{network_id}:#{market_id}") && !refresh
      return Rails.cache.read("market_leaderboard:#{network_id}:#{market_id}")
    end

    actions.each do |action|
      address = action[:address]
      users[address] ||= { earnings: 0, volume: 0, holdings: {}, won_prediction: false }

      case action[:action]
      when 'buy'
        users[address][:earnings] -= action[:value]
        users[address][:volume] += action[:value]
        users[address][:holdings][action[:outcome_id]] ||= { shares: 0, shares_total: 0, shares_value: 0 }
        users[address][:holdings][action[:outcome_id]][:shares] += action[:shares]
        users[address][:holdings][action[:outcome_id]][:shares_total] += action[:shares]
        users[address][:holdings][action[:outcome_id]][:shares_value] += action[:value]
      when 'sell'
        users[address][:earnings] += action[:value]
        users[address][:volume] += action[:value]
        users[address][:holdings][action[:outcome_id]] ||= { shares: 0, shares_total: 0, shares_value: 0 }
        users[address][:holdings][action[:outcome_id]][:shares] -= action[:shares]
      end
    end

    # Calculate holdings value and format the final result
    leaderboard = users.transform_values do |data|
      result = {
        earnings: data[:earnings],
        volume: data[:volume],
        holdings_value: data[:holdings].sum do |outcome_id, holdings|
          holdings[:shares] > 1 && (!market.resolved? || market.voided) ? holdings[:shares] * market.outcome_current_prices[outcome_id] : 0
        end,
        holdings_cost: data[:holdings].sum do |outcome_id, holdings|
          holdings[:shares] > 1 && (!market.resolved? || market.voided) ? holdings[:shares_value] / holdings[:shares_total] : 0
        end,
      }

      if market.resolved? &&
          data[:holdings][market.resolved_outcome_id].present? &&
          data[:holdings][market.resolved_outcome_id][:shares] > 1
        result[:won_prediction] = true
        result[:earnings] += data[:holdings][market.resolved_outcome_id][:shares] * market.outcome_current_prices[market.resolved_outcome_id]
      end

      result
    end

    leaderboard = leaderboard.sort_by { |user, data| -data[:earnings] }

    # write leaderboard to cache if market is resolved
    if market.resolved?
      Rails.cache.write("market_leaderboard:#{network_id}:#{market_id}", leaderboard)
    end

    leaderboard
  end

  def calculate_tournament_leaderboard(network_id, tournament_id)
    tournament = Tournament.find_by(id: tournament_id, network_id: network_id)
    return {} if tournament.blank?

    market_ids = tournament.markets.pluck(:eth_market_id)
    market_leaderboards = market_ids.map do |market_id|
      calculate_market_leaderboard(network_id, market_id)
    end

    leaderboard = merge_market_leaderboards(market_leaderboards)

    # sorting by holdings
    leaderboard.sort_by { |user, data| -data[:earnings] }
  end

  def calculate_tournament_group_leaderboard(network_id, tournament_group_id)
    tournament_group = TournamentGroup.find_by(id: tournament_group_id, network_id: network_id)
    return {} if tournament_group.blank?

    market_ids = tournament_group.markets.pluck(:eth_market_id)
    market_leaderboards = market_ids.map do |market_id|
      calculate_market_leaderboard(network_id, market_id)
    end

    leaderboard = merge_market_leaderboards(market_leaderboards)

    # sorting by holdings
    leaderboard.sort_by { |user, data| -data[:earnings] }
  end

  def merge_market_leaderboards(market_leaderboards)
    leaderboard = market_leaderboards.reduce({}) do |acc, market_leaderboard|
      market_leaderboard.each do |user, data|
        acc[user] ||= { won_predictions: 0, earnings: 0, volume: 0, holdings_value: 0, holdings_cost: 0 }
        acc[user][:won_predictions] += data[:won_prediction] ? 1 : 0
        acc[user][:earnings] += data[:earnings]
        acc[user][:volume] += data[:volume]
        acc[user][:holdings_value] += data[:holdings_value]
        acc[user][:holdings_cost] += data[:holdings_cost]
      end

      acc
    end
  end
end
