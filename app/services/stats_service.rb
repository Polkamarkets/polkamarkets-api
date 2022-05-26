class StatsService
  include NetworkHelper

  attr_accessor :networks, :categories

  TX_ACTIONS = [
    'buy',
    'sell',
    'add_liquidity',
    'remove_liquidity',
  ].freeze

  TIMEFRAMES = {
    '1d' => 'day',
    '1w' => 'week',
    '1m' => 'month'
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
          contract_address: Rails.application.config_for(:ethereum)[:"stats_network_#{network_id}"][:prediction_market_contract_address],
          api_url: Rails.application.config_for(:ethereum)[:"stats_network_#{network_id}"][:bepro_api_url]
        ),
        bepro_realitio: Bepro::RealitioErc20ContractService.new(
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

    stats[:total] = {
      markets_created: stats.values.sum { |v| v[:markets_created] },
      bond_volume_eur: stats.values.sum { |v| v[:bond_volume_eur] },
      volume_eur: stats.values.sum { |v| v[:volume_eur] },
      fees_eur: stats.values.sum { |v| v[:fees_eur] },
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
            timestamp_at(action[:timestamp], timeframe)
          end

          # fetching rate and fee values to avoid multiple API calls
          rate = rate(network_id)
          fee = network[:bepro_pm].get_fee

          [
            network_id,
            actions_by_timeframe.map do |timestamp, timeframe_actions|
              # summing actions values by tx_action
              volume_by_tx_action = TX_ACTIONS.to_h do |action|
                [
                  action,
                  timeframe_actions.select { |a| a[:action] == action }.sum { |a| a[:value] }
                ]
              end

              {
                timestamp: timestamp,
                markets_created: create_market_actions.select { |action| timestamp_at(action[:timestamp], timeframe) == timestamp }.count,
                volume: volume_by_tx_action['buy'] + volume_by_tx_action['sell'],
                volume_eur: (volume_by_tx_action['buy'] + volume_by_tx_action['sell']) * rate,
                tvl_volume: volume_by_tx_action['buy'] - volume_by_tx_action['sell'],
                tvl_volume_eur: (volume_by_tx_action['buy'] - volume_by_tx_action['sell']) * rate,
                liquidity: volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity'],
                liquidity_eur: (volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity']) * rate,
                tvl_liquidity: volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity'],
                tvl_liquidity_eur: (volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity']) * rate,
                fees: (volume_by_tx_action['buy'] + volume_by_tx_action['sell']) * fee,
                fees_eur: (volume_by_tx_action['buy'] + volume_by_tx_action['sell']) * fee * rate,
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
            timestamp_at(action[:timestamp], timeframe)
          end

          [
            category,
            actions_by_timeframe.map do |timestamp, timeframe_actions|
              # summing actions values by tx_action
              volume_by_tx_action = TX_ACTIONS.to_h do |action|
                [
                  action,
                  timeframe_actions.select { |v| v[:action] == action }.group_by { |v| v[:network_id] }.map { |network_id, v| v.sum { |v| v[:value] * rate(network_id) } }.sum
                ]
              end

              {
                timestamp: timestamp,
                markets_created: create_market_actions.select { |action| timestamp_at(action[:timestamp], timeframe) == timestamp }.count,
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
            fees_eur: timeframe_stats.sum { |v| v[:fees_eur] },
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

  def get_leaderboard(timeframe: '1d', refresh: true)
    raise "Invalid timeframe: #{timeframe}" unless TIMEFRAMES.key?(timeframe)

    from = timestamp_at(Time.now.to_i, timeframe)
    to = from + 1.send(TIMEFRAMES[timeframe])

    leaderboard =
      Rails.cache.fetch("api:leaderboard:#{timeframe}", expires_in: 24.hours, force: refresh) do
        stats = {}

        stats[:networks] = networks.to_h do |network|
          network_id = network[:network_id]
          actions = network_actions(network_id)
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

          create_market_actions.select! do |action|
            (!from || action[:timestamp] >= from) &&
              (!to || action[:timestamp] <= to)
          end

          # grouping actions by intervals
          actions_by_user = actions.group_by do |action|
            action[:address]
          end

          # fetching rate and fee values to avoid multiple API calls
          rate = rate(network_id)
          fee = network[:bepro_pm].get_fee

          [
            network_id,
            actions_by_user.map do |user, user_actions|
              # summing actions values by tx_action
              volume_by_tx_action = TX_ACTIONS.to_h do |action|
                [
                  action,
                  user_actions.select { |a| a[:action] == action }.sum { |a| a[:value] }
                ]
              end

              {
                user: user,
                markets_created: create_market_actions.select { |action| action[:address] == user }.count,
                volume: volume_by_tx_action['buy'] + volume_by_tx_action['sell'],
                volume_eur: (volume_by_tx_action['buy'] + volume_by_tx_action['sell']) * rate,
                tvl_volume: volume_by_tx_action['buy'] - volume_by_tx_action['sell'],
                tvl_volume_eur: (volume_by_tx_action['buy'] - volume_by_tx_action['sell']) * rate,
                liquidity: volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity'],
                liquidity_eur: (volume_by_tx_action['add_liquidity'] + volume_by_tx_action['remove_liquidity']) * rate,
                tvl_liquidity: volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity'],
                tvl_liquidity_eur: (volume_by_tx_action['add_liquidity'] - volume_by_tx_action['remove_liquidity']) * rate,
                claim_winnings_count: user_actions.select { |a| a[:action] == 'claim_winnings' }.count,
                transactions: user_actions.count
              }
            end.sort_by { |user| -user[:volume_eur] }
          ]
        end

        stats
      end
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

  def timestamp_at(timestamp, timeframe)
    Time.at(timestamp).utc.public_send("beginning_of_#{TIMEFRAMES[timeframe]}").to_i
  end

  private

  def network_ids
    @_network_ids ||= Rails.application.config_for(:ethereum).network_ids
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
end
