class LeaderboardService
  def calculate_market_leaderboard(network_id, market_id, refresh: false)
    market = Market.find_by(eth_market_id: market_id, network_id: network_id)
    return {} if market.blank? || market.eth_market_id.blank?

    actions = market.action_events
    users = {}

    if Rails.cache.exist?("leaderboard:market:#{network_id}:#{market_id}") && !refresh
      return Rails.cache.read("leaderboard:market:#{network_id}:#{market_id}")
    end

    market_is_voided = market.voided
    market_is_resolved = market.resolved?
    market_resolved_outcome_id = market.resolved_outcome_id
    market_outcome_current_prices = market.outcome_current_prices

    actions.each_with_index do |action, index|
      address = action[:address]
      users[address] ||= {
        earnings: 0,
        volume: 0,
        holdings: {},
        won_prediction: false,
        lost_prediction: false,
        transactions: 0,
        buys: 0
      }
      users[address][:transactions] += 1

      case action[:action]
      when 'buy'
        users[address][:buys] += 1
        users[address][:earnings] -= action[:value]
        users[address][:volume] += action[:value]
        users[address][:holdings][action[:outcome_id]] ||= { shares: 0, shares_total: 0, shares_value: 0, value: 0 }
        users[address][:holdings][action[:outcome_id]][:value] += action[:value]
        users[address][:holdings][action[:outcome_id]][:shares] += action[:shares]
        users[address][:holdings][action[:outcome_id]][:shares_total] += action[:shares]
        users[address][:holdings][action[:outcome_id]][:shares_value] += action[:value]
        users[address][:holdings][action[:outcome_id]][:timestamp] ||= action[:timestamp]
      when 'sell'
        users[address][:earnings] += action[:value]
        users[address][:volume] += action[:value]
        users[address][:holdings][action[:outcome_id]] ||= { shares: 0, shares_total: 0, shares_value: 0, value: 0 }
        users[address][:holdings][action[:outcome_id]][:shares] -= action[:shares]
        users[address][:holdings][action[:outcome_id]][:value] -= action[:value]
      end
    end

    # Calculate holdings value and format the final result
    leaderboard = users.transform_values.with_index do |data, index|
      holdings_value = data[:holdings].sum do |outcome_id, holdings|
        holdings[:shares] > 1 ? holdings[:shares] * market_outcome_current_prices[outcome_id] : 0
      end

      holdings_cost = data[:holdings].sum do |outcome_id, holdings|
        holdings[:shares] > 1 ? holdings[:shares_value] / holdings[:shares_total] * holdings[:shares] : 0
      end

      holdings_count = data[:holdings].count { |outcome_id, holdings| holdings[:shares] > 1 }
      holdings_most_bought_outcome_id = nil
      if holdings_count > 1
        # fetching most bought outcome
        holdings_most_bought_outcome_id = data[:holdings].sort_by do |outcome_id, holdings|
          [-holdings[:value], holdings[:timestamp]]
        end.first.first
      end

      result = {
        earnings: data[:earnings] + holdings_value,
        volume: data[:volume],
        transactions: data[:transactions],
        buys: data[:buys],
        holdings_value: data[:holdings].sum do |outcome_id, holdings|
          !market_is_resolved ? holdings_value : 0
        end,
        holdings_cost: data[:holdings].sum do |outcome_id, holdings|
          !market_is_resolved ? holdings_cost : 0
        end,
        winnings: data[:earnings] + (market_is_resolved ? holdings_value : 0) + (!market_is_resolved ? holdings_cost : 0)
      }

      if market_is_resolved &&
          data[:holdings][market_resolved_outcome_id].present? &&
          data[:holdings][market_resolved_outcome_id][:shares] > 1 &&
          (holdings_count <= 1 || holdings_most_bought_outcome_id == market_resolved_outcome_id)
        result[:won_prediction] = true
      elsif market_is_resolved &&
        data[:holdings][holdings_most_bought_outcome_id].present? &&
        data[:holdings][holdings_most_bought_outcome_id][:shares] > 1 &&
        (holdings_most_bought_outcome_id != market_resolved_outcome_id)
        result[:lost_prediction] = true
      end

      result
    end

    leaderboard = leaderboard.sort_by { |user, data| -data[:earnings] }

    # write leaderboard to cache if market is resolved
    if market_is_resolved
      Rails.cache.write("leaderboard:market:#{network_id}:#{market_id}", leaderboard)
    end

    leaderboard
  end

  def calculate_tournament_leaderboard(network_id, tournament_id)
    tournament = Tournament.find_by(id: tournament_id, network_id: network_id)
    return {} if tournament.blank?

    market_ids = tournament.markets.pluck(:eth_market_id).compact
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

    market_ids = tournament_group.markets.pluck(:eth_market_id).compact
    market_leaderboards = market_ids.map do |market_id|
      calculate_market_leaderboard(network_id, market_id)
    end

    leaderboard = merge_market_leaderboards(market_leaderboards)

    # sorting by holdings
    leaderboard.sort_by { |user, data| -data[:earnings] }
  end

  def calculate_network_leaderboard(network_id)
    market_ids = Market.where(network_id: network_id).pluck(:eth_market_id).compact

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
        acc[user] ||= {
          won_predictions: 0,
          lost_predictions: 0,
          earnings: 0,
          volume: 0,
          holdings_value: 0,
          holdings_cost: 0,
          winnings: 0,
          transactions: 0,
          buys: 0
        }
        acc[user][:won_predictions] += data[:won_prediction] ? 1 : 0
        acc[user][:lost_predictions] += data[:lost_prediction] ? 1 : 0
        acc[user][:earnings] += data[:earnings]
        acc[user][:volume] += data[:volume]
        acc[user][:holdings_value] += data[:holdings_value]
        acc[user][:holdings_cost] += data[:holdings_cost]
        acc[user][:winnings] += data[:winnings]
        acc[user][:transactions] += data[:transactions]
        acc[user][:buys] += data[:buys]
      end

      acc
    end
  end

  def sum_leaderboard_data(leaderboard)
    leaderboard.reduce({
      won_predictions: 0,
      lost_predictions: 0,
      earnings: 0,
      volume: 0,
      holdings_value: 0,
      holdings_cost: 0,
      winnings: 0,
      transactions: 0,
      buys: 0,
      users: leaderboard.count
    }) do |acc, data|
      acc[:won_predictions] += data[1][:won_predictions]
      acc[:lost_predictions] += data[1][:lost_predictions]
      acc[:earnings] += data[1][:earnings]
      acc[:volume] += data[1][:volume]
      acc[:holdings_value] += data[1][:holdings_value]
      acc[:holdings_cost] += data[1][:holdings_cost]
      acc[:winnings] += data[1][:winnings]
      acc[:transactions] += data[1][:transactions]
      acc[:buys] += data[1][:buys]

      acc
    end
  end

  def get_tournament_leaderboard(network_id, tournament_id, refresh: false)
    if Rails.cache.exist?("leaderboard:tournament:#{network_id}:#{tournament_id}") && !refresh
      return Rails.cache.read("leaderboard:tournament:#{network_id}:#{tournament_id}")
    end

    leaderboard = calculate_tournament_leaderboard(network_id, tournament_id)
    leaderboard_legacy = format_in_legacy_format(network_id, leaderboard)

    Rails.cache.write("leaderboard:tournament:#{network_id}:#{tournament_id}", leaderboard_legacy)

    leaderboard_legacy
  end

  def get_tournament_group_leaderboard(network_id, tournament_group_id, refresh: false)
    if Rails.cache.exist?("leaderboard:tournament_group:#{network_id}:#{tournament_group_id}") && !refresh
      return Rails.cache.read("leaderboard:tournament_group:#{network_id}:#{tournament_group_id}")
    end

    leaderboard = calculate_tournament_group_leaderboard(network_id, tournament_group_id)
    leaderboard_legacy = format_in_legacy_format(network_id, leaderboard)

    Rails.cache.write("leaderboard:tournament_group:#{network_id}:#{tournament_group_id}", leaderboard_legacy)

    leaderboard_legacy
  end

  def get_network_leaderboard(network_id, refresh: false)
    if Rails.cache.exist?("leaderboard:network:#{network_id}") && !refresh
      return Rails.cache.read("leaderboard:network:#{network_id}")
    end

    leaderboard = calculate_network_leaderboard(network_id)
    leaderboard_legacy = format_in_legacy_format(network_id, leaderboard)

    Rails.cache.write("leaderboard:network:#{network_id}", leaderboard_legacy)

    leaderboard_legacy
  end

  def format_in_legacy_format(network_id, leaderboard)
    # filtering out empty users, blacklist and backfilling user data
    users = User.where.not(wallet_address: nil).pluck(:username, :wallet_address, :avatar, :slug, :origin)
    users_hash = {}

    blacklist = Rails.application.config_for(:ethereum).blacklist
    blacklist_hash = blacklist.map { |address| [address.downcase, true] }.to_h

    # populating users_hash hash
    users.each do |user|
      users_hash[user[1].downcase] = user
    end

    leaderboard.map do |address, data|
      user = users_hash[address.downcase]

      # skipping blacklisted users
      next if blacklist_hash[address.downcase]

      {
        user: address,
        ens: nil,
        markets_created: 0,
        verified_markets_created: 0,
        volume_eur: data[:volume],
        tvl_volume_eur: 0,
        earnings_eur: data[:earnings],
        earnings_open_eur: data[:holdings_value] - data[:holdings_cost],
        earnings_closed_eur: data[:winnings],
        liquidity_eur: 0,
        tvl_liquidity_eur: 0,
        bond_volume: 0,
        claim_winnings_count: data[:won_predictions],
        lost_winnings_count: data[:lost_predictions],
        transactions: data[:transactions],
        buys: data[:buys],
        upvotes: 0,
        downvotes: 0,
        malicious: false,
        bankrupt: false,
        needs_rescue: false,
        username: user ? user[0] : nil,
        user_image_url: user ? user[2] : nil,
        slug: user ? user[3] : nil,
        origin: user ? user[4] : nil
      }
    end.compact
  end
end
