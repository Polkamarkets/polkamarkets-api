class LeaderboardService
  # keys sizes are minified for optimization purposes
  REDIS_MAPPINGS = {
    volume_eur: 'v',
    earnings_eur: 'e',
    earnings_open_eur: 'eo',
    earnings_closed_eur: 'ec',
    claim_winnings_count: 'wp',
    lost_winnings_count: 'lp',
    transactions: 't',
    buys: 'b',
    username: 'u',
    user_image_url: 'ui',
    slug: 's',
    origin: 'o'
  }.freeze

  def calculate_market_leaderboard(network_id, market_id, refresh: true)
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
    market_should_refund_voided_markets = market.refund_voided_markets?
    market_delta_leaderboard = get_market_delta_leaderboard(network_id, market_id)

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

      # losses are refunded on voided markets with refund_voided_markets flag enabled
      data[:earnings] = 0 if market_is_voided && market_should_refund_voided_markets && data[:earnings] < 0

      if market_delta_leaderboard.present?
        address = users.keys[index]
        data[:earnings] += market_delta_leaderboard[address] if market_delta_leaderboard[address].present?
      end

      result = {
        earnings: data[:earnings] + (market_is_voided && market_should_refund_voided_markets ? 0 : holdings_value),
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

  def get_market_delta_leaderboard(network_id, market_id)
    Rails.cache.read("leaderboard:market:#{network_id}:#{market_id}:delta")
  end

  def get_tournament_leaderboard(
    network_id,
    tournament_id,
    refresh: false,
    from: 0,
    to: 99,
    rank_by: 'earnings',
    sort: 'desc'
  )
    cache_key = "leaderboard:tournament:#{network_id}:#{tournament_id}"

    if refresh
      leaderboard = calculate_tournament_leaderboard(network_id, tournament_id)
      leaderboard_blacklist = get_tournament_leaderboard_blacklist(tournament_id, leaderboard)
      leaderboard_legacy = format_in_legacy_format(network_id, leaderboard)

      write_leaderboard_to_redis(leaderboard_legacy, cache_key, leaderboard_blacklist)
    end

    leaderboard_legacy = get_leaderboard(cache_key, from: from, to: to, rank_by: rank_by, sort: sort)
    leaderboard_legacy
  end

  def get_tournament_leaderboard_blacklist(tournament_id, leaderboard)
    tournament = Tournament.find(tournament_id)
    return {} unless tournament.rank_by_priority && (tournament.rank_by_priority_places > 0 || tournament.rank_by_priority == 'highest_ranking')

    # TODO: add blacklist from env
    blacklist = {}
    if tournament.rank_by_priority == 'highest_ranking'
      rewards_size = tournament.ranking_rewards_places('earnings_eur')
      earnings_leaderboard = leaderboard
        .sort_by { |user, data| -data[:earnings] }
        .first(rewards_size * 2)
        .map { |user, data| user }
      winnings_leaderboard = leaderboard
        .sort_by { |user, data| -data[:won_predictions] }
        .first(rewards_size * 2)
        .map { |user, data| user }

      blacklist[:earnings] = []
      blacklist[:won_predictions] = []
      # excluding users on both leaderboards from the other leaderboard, based on the top ranking
      0..rewards_size.times do |i|
        earnings_user = earnings_leaderboard[i]
        # finding user ranking on won_predictions leaderboard
        earnings_user_won_predictions_ranking = won_predictions_leaderboard.find_index(earnings_user)
        # removing user from won_predictions leaderboard
        if earnings_user_won_predictions_ranking.present?
          won_predictions_leaderboard.delete(earnings_user)
          blacklist[:won_predictions] << earnings_user
        end

        won_predictions_user = won_predictions_leaderboard[i]
        # finding user ranking on earnings leaderboard
        won_predictions_user_earnings_ranking = earnings_leaderboard.find_index(won_predictions_user)
        # removing user from earnings leaderboard
        if won_predictions_user_earnings_ranking.present?
          earnings_leaderboard.delete(won_predictions_user)
          blacklist[:earnings] << won_predictions_user
        end
      end
    else
      blacklist_criteria = tournament.rank_by_priority == 'earnings_eur' ? :won_predictions : :earnings
      blacklist_rank_by = tournament.rank_by_priority == 'earnings_eur' ? :earnings : :won_predictions

      blacklist[blacklist_criteria] = leaderboard
        .sort_by { |user, data| -data[blacklist_rank_by] }
        .first(tournament.rank_by_priority_places)
        .map { |user, data| user }
    end

    blacklist
  end

  def get_tournament_group_leaderboard(
    network_id,
    tournament_group_id,
    refresh: false,
    from: 0,
    to: 99,
    rank_by: 'earnings',
    sort: 'desc'
  )
    cache_key = "leaderboard:tournament_group:#{network_id}:#{tournament_group_id}"

    if refresh
      leaderboard = calculate_tournament_group_leaderboard(network_id, tournament_group_id)
      leaderboard_legacy = format_in_legacy_format(network_id, leaderboard)

      write_leaderboard_to_redis(leaderboard_legacy, cache_key)
    end

    leaderboard_legacy = get_leaderboard(cache_key, from: from, to: to, rank_by: rank_by, sort: sort)
    leaderboard_legacy
  end

  def get_leaderboard(cache_key, from: 0, to: 99, rank_by: 'earnings', sort: 'desc')
    count = get_leaderboard_size("#{cache_key}:#{rank_by}")

    leaderboard = sort == 'asc' ?
      $redis_store.zrange("#{cache_key}:#{rank_by}", from, to) :
      $redis_store.zrevrange("#{cache_key}:#{rank_by}", from, to)

    data = leaderboard.map do |user|
      get_user_leaderboard_entry(user, cache_key)
    end

    {
      data: data,
      count: count
    }
  end

  def get_leaderboard_size(cache_key)
    $redis_store.zcard(cache_key)
  end

  def get_tournament_leaderboard_user_entry(network_id, tournament_id, user)
    cache_key = "leaderboard:tournament:#{network_id}:#{tournament_id}"
    get_user_leaderboard_entry(user, cache_key)
  end

  def get_tournament_group_leaderboard_user_entry(network_id, tournament_group_id, user)
    cache_key = "leaderboard:tournament_group:#{network_id}:#{tournament_group_id}"
    get_user_leaderboard_entry(user, cache_key)
  end

  def get_user_leaderboard_entry(user, cache_key)
    leaderboard_entry = $redis_store.get("#{cache_key}:data:#{user}")
    return nil if leaderboard_entry.blank?

    entry = map_redis_entry_to_leaderboard(leaderboard_entry, user)

    # fetching rankings
    earnings_rank = $redis_store.zrevrank("#{cache_key}:earnings", user) || -1
    won_predictions_rank = $redis_store.zrevrank("#{cache_key}:won_predictions", user) || -1

    entry[:rank] = {
      earnings_eur: earnings_rank + 1,
      claim_winnings_count: won_predictions_rank + 1
    }

    entry
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
        volume_eur: data[:volume].round(2),
        earnings_eur: data[:earnings].round(2),
        earnings_open_eur: (data[:holdings_value] - data[:holdings_cost]).round(2),
        earnings_closed_eur: data[:winnings].round(2),
        claim_winnings_count: data[:won_predictions],
        lost_winnings_count: data[:lost_predictions],
        transactions: data[:transactions],
        buys: data[:buys],
        username: user ? user[0] : nil,
        user_image_url: user ? user[2] : nil,
        slug: user ? user[3] : nil,
        origin: user ? user[4] : nil
      }
    end.compact
  end

  def write_leaderboard_to_redis(leaderboard, cache_key, blacklist = {})
    return if leaderboard.blank?

    # ranking by earnings
    earnings = leaderboard.map { |l| [l[:earnings_eur], l[:user]] }
    earnings.reject! { |e| blacklist[:earnings].include?(e[1]) } if blacklist[:earnings].present?

    $redis_store.zadd("#{cache_key}:earnings", earnings)
    $redis_store.zrem("#{cache_key}:earnings", blacklist[:earnings]) if blacklist[:earnings].present?

    # ranking by won predictions
    won_predictions = leaderboard.map do |l|
      [
        # adding earnings as a decimal as a tie breaker
        l[:claim_winnings_count] + l[:earnings_eur] * 1e-12,
        l[:user]
      ]
    end
    won_predictions.reject! { |e| blacklist[:won_predictions].include?(e[1]) } if blacklist[:won_predictions].present?
    $redis_store.zadd("#{cache_key}:won_predictions", won_predictions)
    $redis_store.zrem("#{cache_key}:won_predictions", blacklist[:won_predictions]) if blacklist[:won_predictions].present?

    # writing leaderboard to set
    data = leaderboard.map { |l| ["#{cache_key}:data:#{l[:user]}", map_leaderboard_entry_to_redis(l)] }.flatten
    $redis_store.mset(*data)
  end

  def map_leaderboard_entry_to_redis(entry)
    entry.map do |key, value|
      next unless REDIS_MAPPINGS[key].present?

      [REDIS_MAPPINGS[key], value]
    end.compact.to_h.to_json
  end

  def map_redis_entry_to_leaderboard(entry, user)
    entry = JSON.parse(entry).map do |key, value|
      [REDIS_MAPPINGS.key(key), value]
    end.compact.to_h

    entry[:user] = user
    entry
  end
end
