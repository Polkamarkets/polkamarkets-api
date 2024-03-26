class StatsService
  include NetworkHelper

  attr_accessor :networks, :categories

  TX_ACTIONS = [
    'buy',
    'sell',
    'add_liquidity',
    'remove_liquidity',
    'claim_winnings',
    'claim_voided'
  ].freeze

  TIMEFRAMES = {
    'at' => 'all-time',
    '1d' => 'day',
    '1w' => 'week',
    '1m' => 'month'
  }.freeze

  LEADERBOARD_PARAMS = {
    :volume_eur => { :amount => 3, :value => 250 },
    :tvl_volume_eur => { :amount => 3, :value => 500 },
    :tvl_liquidity_eur => { :amount => 3, :value => 500 },
    :verified_markets_created => { :amount => 3, :value => 250 },
    :bond_volume => { :amount => 5, :value => 100 },
    :upvotes => { :amount => 10, :value => 50 },
    :downvotes => { :amount => 10, :value => 50 }
  }.freeze

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
          network_id: network_id,
          contract_address: Rails.application.config_for(:ethereum)[:"stats_network_#{network_id}"][:prediction_market_contract_address],
          api_url: Rails.application.config_for(:ethereum)[:"stats_network_#{network_id}"][:bepro_api_url]
        ),
        bepro_realitio: Bepro::RealitioErc20ContractService.new(
          network_id: network_id,
          contract_address: Rails.application.config_for(:ethereum)[:"stats_network_#{network_id}"][:realitio_contract_address],
          api_url: Rails.application.config_for(:ethereum)[:"stats_network_#{network_id}"][:bepro_api_url]
        )
      }
    end

    @networks = ethereum_networks + stats_networks
  end

  def get_stats(from: nil, to: nil)
    # TODO: volume chart
    # TODO: TVL chart
    stats = networks.map do |network|
      network_id = network[:network_id]
      actions = network_actions(network_id)
      bonds = network_bonds(network_id)
      market_ids = actions.map { |action| action[:market_id] }.uniq

      create_market_actions = market_ids.map do |market_id|
        # first action represents market creation
        action = actions.find { |action| action[:market_id] == market_id }
      end

      # filtering by timestamps, if provided
      actions.select! do |action|
        (!from || action[:timestamp] >= from) &&
          (!to || action[:timestamp] <= to)
      end

      bonds.select! do |bond|
        (!from || bond[:timestamp] >= from) &&
          (!to || bond[:timestamp] <= to)
      end

      create_market_actions.select! do |action|
        (!from || action[:timestamp] >= from) &&
          (!to || action[:timestamp] <= to)
      end

      markets_created = create_market_actions.count
      volume = actions.select { |v| ['buy', 'sell'].include?(v[:action]) }
      bonds_volume = bonds.sum { |bond| bond[:value] }
      bonds_volume_eur = bonds.sum { |bond| bond[:value] * token_rate_at('polkamarkets', 'eur', bond[:timestamp]) }
      volume_eur = volume.sum do |a|
        action_rate(a, network_id)
      end

      users = actions.map { |a| a[:address] }.uniq.count

      [
        network_id,
        {
          markets_created: markets_created,
          bond_volume: bonds_volume,
          bond_volume_eur: bonds_volume_eur,
          volume_eur: volume_eur,
          users: users,
          transactions: actions.count
        }
      ]
    end.to_h

    stats[:total] = {
      markets_created: stats.values.sum { |v| v[:markets_created] },
      bond_volume_eur: stats.values.sum { |v| v[:bond_volume_eur] },
      volume_eur: stats.values.sum { |v| v[:volume_eur] },
      users: stats.values.sum { |v| v[:users] },
      transactions: stats.values.sum { |v| v[:transactions] }
    }

    stats
  end

  def get_stats_by_timeframe(timeframe: '1d', from: nil, to: nil, refresh: false)
    raise "Invalid timeframe: #{timeframe}" unless TIMEFRAMES.key?(timeframe)

    stats_by_timeframe =
      Rails.cache.fetch("api:stats:#{timeframe}", expires_in: 24.hours, force: refresh) do
        stats = {}
        all_actions = []

        stats[:networks] = networks.to_h do |network|
          network_id = network[:network_id]
          actions = network_actions(network_id)
          # used for category filtering
          all_actions.concat(actions.map { |action| action.merge(network_id: network_id) })
          market_ids = actions.map { |action| action[:market_id] }.uniq

          create_market_actions = market_ids.map do |market_id|
            # first action represents market creation
            action = actions.find { |action| action[:market_id] == market_id }
          end

          # grouping actions by intervals
          actions_by_timeframe = actions.group_by do |action|
            timestamp_from(action[:timestamp], timeframe)
          end

          [
            network_id,
            actions_by_timeframe.map do |timestamp, timeframe_actions|
              # summing actions values by tx_action
              volume_by_tx_action = TX_ACTIONS.to_h do |action|
                [
                  action,
                  timeframe_actions.select { |a| a[:action] == action }.sum do |a|
                    action_rate(a, network_id)
                  end
                ]
              end

              {
                timestamp: timestamp,
                markets_created: create_market_actions.select { |action| timestamp_from(action[:timestamp], timeframe) == timestamp }.count,
                volume_eur: (volume_by_tx_action['buy'] + volume_by_tx_action['sell']),
                tvl_volume_eur: (volume_by_tx_action['buy'] - volume_by_tx_action['sell']),
                liquidity_eur: (volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity']),
                tvl_liquidity_eur: (volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity']),
                users: timeframe_actions.map { |a| a[:address] }.uniq.count,
                transactions: timeframe_actions.count
              }
            end
          ]
        end

        # grouping actions by market category
        stats[:categories] = categories.to_h do |category|
          network_ids = networks.map { |network| network[:network_id] }
          # filtering action events by market category
          actions = all_actions.select do |action|
            markets_by_category[category].find { |market| market[:eth_market_id] == action[:market_id] && market[:network_id] == action[:network_id].to_i }
          end
          market_ids = actions.map { |action| action[:market_id] }.uniq

          create_market_actions = market_ids.map do |market_id|
            # first action represents market creation
            action = actions.find { |action| action[:market_id] == market_id }
          end

          # grouping actions by intervals
          actions_by_timeframe = actions.group_by do |action|
            timestamp_from(action[:timestamp], timeframe)
          end

          [
            category,
            actions_by_timeframe.map do |timestamp, timeframe_actions|
              # summing actions values by tx_action
              volume_by_tx_action = TX_ACTIONS.to_h do |action|
                [
                  action,
                  timeframe_actions
                    .select { |v| v[:action] == action }
                    .group_by { |v| v[:network_id] }
                    .map do |network_id, v|
                      v.sum do |a|
                        action_rate(a, network_id)
                      end
                    end.sum
                ]
              end

              {
                timestamp: timestamp,
                markets_created: create_market_actions.select { |action| timestamp_from(action[:timestamp], timeframe) == timestamp }.count,
                volume_eur: volume_by_tx_action['buy'] + volume_by_tx_action['sell'],
                tvl_volume_eur: volume_by_tx_action['buy'] - volume_by_tx_action['sell'],
                liquidity_eur: volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity'],
                tvl_liquidity_eur: volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity'],
                users: timeframe_actions.map { |a| a[:address] }.uniq.count,
                transactions: timeframe_actions.count
              }
            end
          ]
        end

        stats[:total] = stats[:networks].values.flatten.group_by { |v| v[:timestamp] }.map do |timestamp, timeframe_stats|
          {
            timestamp: timestamp,
            markets_created: timeframe_stats.sum { |v| v[:markets_created] },
            volume_eur: timeframe_stats.sum { |v| v[:volume_eur] },
            tvl_volume_eur: timeframe_stats.sum { |v| v[:tvl_volume_eur] },
            liquidity_eur: timeframe_stats.sum { |v| v[:liquidity_eur] },
            tvl_liquidity_eur: timeframe_stats.sum { |v| v[:tvl_liquidity_eur] },
            users: timeframe_stats.sum { |v| v[:users] },
            transactions: timeframe_stats.sum { |v| v[:transactions] }
          }
        end

        stats
      end

    # filtering stats by timestamps
    stats_by_timeframe[:total].select! do |stat|
      (from.blank? || stat[:timestamp] >= from.to_i) &&
        (to.blank? || stat[:timestamp] <= to.to_i)
    end
    stats_by_timeframe[:networks] = stats_by_timeframe[:networks].to_h do |network, network_stats|
      [
        network,
        network_stats.select do |stat|
          (from.blank? || stat[:timestamp] >= from.to_i) &&
            (to.blank? || stat[:timestamp] <= to.to_i)
        end
      ]
    end
    stats_by_timeframe[:categories] = stats_by_timeframe[:categories].to_h do |category, category_stats|
      [
        category,
        category_stats.select do |stat|
          (from.blank? || stat[:timestamp] >= from.to_i) &&
            (to.blank? || stat[:timestamp] <= to.to_i)
        end
      ]
    end

    stats_by_timeframe
  end

  def get_leaderboard(timeframe:, refresh: false, timestamp: Time.now.to_i, tournament_id: nil)
    raise "Invalid timeframe: #{timeframe}" unless TIMEFRAMES.key?(timeframe)

    from = timestamp_from(timestamp, timeframe)
    to = timestamp_to(timestamp, timeframe)

    tournament = Tournament.find_by(id: tournament_id)

    leaderboard =
      networks.to_h do |network|
        network_id = network[:network_id]

        key = "api:leaderboard:#{timeframe}:#{from}:#{to}:#{network_id}"
        key << ":#{tournament_id}" if tournament.present? && tournament.network_id == network_id.to_i

        Rails.cache.fetch(key, expires_in: 24.hours, force: refresh) do
          actions = network_actions(network_id)
          bonds = network_bonds(network_id)
          votes = network_votes(network_id)
          burn_actions = network_burn_actions(network_id)
          markets_resolved = network_markets_resolved(network_id)

          tournament_market_ids = tournament.markets.map(&:eth_market_id) if tournament.present? && tournament.network_id == network_id.to_i

          market_ids = actions.map { |action| action[:market_id] }.uniq
          market_ids = market_ids & tournament_market_ids if tournament_market_ids.present?

          create_market_actions = market_ids.map do |market_id|
            # first action represents market creation
            action = actions.find { |action| action[:market_id] == market_id }
          end

          # filtering by timestamps, if provided
          actions.select! do |action|
            (!from || action[:timestamp] >= from) &&
              (!to || action[:timestamp] <= to) &&
              (tournament_market_ids.blank? || tournament_market_ids.include?(action[:market_id]))
          end

          bonds.select! do |bond|
            (!from || bond[:timestamp] >= from) &&
              (!to || bond[:timestamp] <= to)
          end

          create_market_actions.select! do |action|
            (!from || action[:timestamp] >= from) &&
              (!to || action[:timestamp] <= to)
          end

          upvote_actions = votes.select do |action|
            action[:action] == 'upvote' &&
              (!from || action[:timestamp] >= from) &&
              (!to || action[:timestamp] <= to) &&
              (tournament_market_ids.blank? || tournament_market_ids.include?(action[:item_id]))
          end

          downvote_actions = votes.select do |action|
            action[:action] == 'downvote' &&
              (!from || action[:timestamp] >= from) &&
              (!to || action[:timestamp] <= to) &&
              (tournament_market_ids.blank? || tournament_market_ids.include?(action[:item_id]))
          end

          markets_resolved.select! do |action|
            (!from || action[:timestamp] >= from) &&
              (!to || action[:timestamp] <= to) &&
              (tournament_market_ids.blank? || tournament_market_ids.include?(action[:market_id]))
          end

          # grouping actions by intervals
          actions_by_user = actions.group_by do |action|
            action[:address]
          end

          # adding any missing users from voting actions or bonds to the leaderboard
          users = upvote_actions.map { |a| a[:user] } +
            downvote_actions.map { |a| a[:user] } +
            bonds.map { |a| a[:user] }

          users.uniq.each do |user|
            actions_by_user[user] ||= []
          end

          network_leaderboard =
            actions_by_user.map do |user, user_actions|
              # summing actions values by tx_action
              volume_by_tx_action = TX_ACTIONS.to_h do |action|
                [
                  action,
                  user_actions.select { |a| a[:action] == action }.sum do |a| a[:value]
                    action_rate(a, network_id)
                  end
                ]
              end

              portfolio_value = 0
              portfolio_cost = 0
              winnings_value = 0
              is_sybil_attacker = { is_attacker: false }
              bankrupt_data = { bankrupt: false, needs_rescue: false }
              claim_winnings_count = 0

              if Rails.application.config_for(:ethereum).fantasy_enabled
                portfolio = Portfolio.new(eth_address: user.downcase, network_id: network_id)
                # calculating portfolio value to add to earnings
                burn_total = burn_actions.select { |action| action[:from] == user }.sum { |action| action[:value] }
                portfolio_value = portfolio.holdings_value(filter_by_market_ids: tournament_market_ids) - burn_total
                portfolio_cost = portfolio.holdings_cost(filter_by_market_ids: tournament_market_ids)

                # calculating winnings value to add to earnings
                winnings = portfolio.closed_markets_winnings(
                  filter_by_market_ids: markets_resolved.map { |action| action[:market_id] }
                )

                claim_winnings_count = winnings[:count]
                winnings_value = winnings[:value]

                if Rails.application.config_for(:ethereum).fantasy_advanced_mode
                  is_sybil_attacker = SybilAttackFinderService.new(user, network_id).is_sybil_attacker?
                  bankrupt_data = BankruptcyFinderService.new(user, network_id).is_bankrupt?
                end
              else
                claim_winnings_count = user_actions.select { |a| a[:action] == 'claim_winnings' }.count
                winnings_value = volume_by_tx_action['claim_winnings'] + volume_by_tx_action['claim_voided']
              end

              {
                user: user,
                ens: EnsService.new.cached_ens_domain(address: user),
                markets_created: create_market_actions.select { |action| action[:address] == user }.count,
                verified_markets_created: create_market_actions.select { |action| action[:address] == user && network_verified_market_ids(network_id).include?(action[:market_id]) }.count,
                volume_eur: volume_by_tx_action['buy'] + volume_by_tx_action['sell'],
                tvl_volume_eur: volume_by_tx_action['buy'] - volume_by_tx_action['sell'],
                earnings_eur: volume_by_tx_action['sell'] - volume_by_tx_action['buy'] + portfolio_value + winnings_value,
                earnings_open_eur: portfolio_value - portfolio_cost,
                earnings_closed_eur: volume_by_tx_action['sell'] - volume_by_tx_action['buy'] + winnings_value + portfolio_cost,
                liquidity_eur: volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity'],
                tvl_liquidity_eur: volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity'],
                bond_volume: bonds.select { |bond| bond[:user] == user }.sum { |bond| bond[:value] },
                claim_winnings_count: claim_winnings_count,
                transactions: user_actions.count,
                upvotes: upvote_actions.select { |action| action[:user] == user }.count,
                downvotes: downvote_actions.select { |action| action[:user] == user }.count,
                malicious: is_sybil_attacker[:is_attacker],
                bankrupt: bankrupt_data[:bankrupt],
                needs_rescue: bankrupt_data[:needs_rescue]
              }
            end

          [
            network_id.to_i,
            filtered_leaderboard(network_leaderboard)
          ]
        end
      end
  end

  def rate(network_id)
    token = TokenRatesService::NETWORK_TOKENS[network_id.to_i]

    return 0 if token.blank?

    rates[token.to_sym]
  end

  def network_rate_at(network_id, currency, timestamp)
    token = TokenRatesService::NETWORK_TOKENS[network_id.to_i]

    return 0 if token.blank?

    token_rate_at(token, currency, timestamp)
  end

  def token_rate_at(token, currency, timestamp)
    TokenRatesService.new.get_token_rate_at(token, currency, timestamp)
  end

  def action_rate(action, network_id)
    market = all_markets.find { |m| m.eth_market_id == action[:market_id] && m.network_id.to_i == network_id.to_i }
    market.present? ? action[:value] * market.token_rate_at(action[:timestamp]) : 0
  end

  def rates
    @_rates ||= TokenRatesService.new.get_rates(
      TokenRatesService::NETWORK_TOKENS.map { |_n, token| token } + ['polkamarkets'],
      'eur'
    )
  end

  def timestamp_from(timestamp, timeframe)
    return 0 if TIMEFRAMES[timeframe] == 'all-time'

    # weekly timeframe starts on Fridays due to the rewarding system
    args = TIMEFRAMES[timeframe] == 'week' ? [:friday] : []

    date = Time.at(timestamp).utc.public_send("beginning_of_#{TIMEFRAMES[timeframe]}", *args).to_i
  end

  def timestamp_to(timestamp, timeframe)
    # setting to next 1-day block if timeframe is all time
    return (Time.now.to_i / 86400 + 2) * 86400 if TIMEFRAMES[timeframe] == 'all-time'

    # weekly timeframe starts on Fridays due to the rewarding system
    args = TIMEFRAMES[timeframe] == 'week' ? [:friday] : []

    date = Time.at(timestamp).utc.public_send("end_of_#{TIMEFRAMES[timeframe]}", *args).to_i
  end

  def filtered_leaderboard(leaderboard)
    # filtering out empty users, blacklist and backfilling user data
    users = User.pluck(:username, :wallet_address, :avatar, :slug)

    leaderboard.each do |user|
      user_data = users.find { |data| data[1].present? && data[1].downcase == user[:user].downcase }

      user[:username] = user_data ? user_data[0] : nil
      user[:user_image_url] = user_data ? user_data[2] : nil
      user[:slug] = user_data ? user_data[3] : nil
    end

    # removing blacklisted users from leaderboard
    leaderboard.reject! { |l| l[:user].in?(Rails.application.config_for(:ethereum).blacklist) }

    # removing users only with upvotes/downvotes
    leaderboard.reject! { |l| l[:transactions] == 0 }

    leaderboard
  end

  private

  def network_ids
    @_network_ids ||= Rails.application.config_for(:ethereum).network_ids
  end

  def network_verified_market_ids(network_id)
    return @network_verified_market_ids&.dig(network_id) if !@network_verified_market_ids&.dig(network_id).nil?

    @network_verified_market_ids ||= {}

    market_ids = Market.where(network_id: network_id).where(eth_market_id: market_list.market_ids(network_id.to_i)).pluck(:eth_market_id)
    market_ids += Market.where(slug: market_list.market_slugs(network_id.to_i)).pluck(:eth_market_id)
    # fetching all markets with a positive delta of votes
    market_ids += Market.where(network_id: network_id).select do |market|
      market.votes_delta >= Rails.application.config_for(:ethereum).voting_delta
    end.pluck(:eth_market_id)

    @network_verified_market_ids[network_id] = market_ids.uniq
  end

  def stats_network_ids
    @_stats_network_ids ||= Rails.application.config_for(:ethereum).stats_network_ids
  end

  def categories
    @_categories ||= Market.pluck(:category).uniq
  end

  def markets_by_category
    @_markets_by_category ||= Market.all.group_by(&:category)
  end

  def all_markets
    @_all_markets ||= Market.all.to_a
  end

  def market_list
    @_market_list ||= MarketListService.new(Rails.application.config_for(:ethereum).market_list_url)
  end
end
