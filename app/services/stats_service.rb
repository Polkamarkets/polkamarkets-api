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
      actions = network[:bepro_pm].get_action_events
      bonds = network[:bepro_realitio].get_bond_events
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

  def get_stats_daily(from: nil, to: nil)
    stats = networks.map do |network|
      network_id = network[:network_id]
      actions = network[:bepro_pm].get_action_events
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

      # grouping actions by day intervals
      actions_by_day = actions.group_by { |action| Time.at(action[:timestamp]).utc.beginning_of_day.to_i }

      # fetching rate and fee values to avoid multiple API calls
      rate = rate(network_id)
      fee = network[:bepro_pm].get_fee

      [
        network_id,
        actions_by_day.map do |timestamp, day_actions|
          {
            timestamp: timestamp,
            markets_created: create_market_actions.select { |action| action[:timestamp].between?(timestamp, timestamp + 1.day.to_i) }.count,
            volume: day_actions.select { |v| ['buy', 'sell'].include?(v[:action]) }.sum { |v| v[:value] },
            volume_eur: day_actions.select { |v| ['buy', 'sell'].include?(v[:action]) }.sum { |v| v[:value] } * rate,
            tvl_volume: day_actions.select { |v| v[:action] == 'buy' }.sum { |v| v[:value] } - day_actions.select { |v| v[:action] == 'sell' }.sum { |v| v[:value] },
            tvl_volume_eur: (day_actions.select { |v| v[:action] == 'buy' }.sum { |v| v[:value] } - day_actions.select { |v| v[:action] == 'sell' }.sum { |v| v[:value] }) * rate,
            liquidity: day_actions.select { |v| ['add_liquidity', 'remove_liquidity'].include?(v[:action]) }.sum { |v| v[:value] },
            liquidity_eur: day_actions.select { |v| ['add_liquidity', 'remove_liquidity'].include?(v[:action]) }.sum { |v| v[:value] } * rate,
            tvl_liquidity: day_actions.select { |v| v[:action] == 'add_liquidity' }.sum { |v| v[:value] } - day_actions.select { |v| v[:action] == 'remove_liquidity' }.sum { |v| v[:value] },
            tvl_liquidity_eur: (day_actions.select { |v| v[:action] == 'add_liquidity' }.sum { |v| v[:value] } - day_actions.select { |v| v[:action] == 'remove_liquidity' }.sum { |v| v[:value] }) * rate,
            fees: day_actions.sum { |v| v[:value] } * fee,
            fees_eur: day_actions.sum { |v| v[:value] } * fee * rate,
            users: day_actions.map { |a| a[:address] }.uniq.count,
            transactions: day_actions.count
          }
        end
      ]
    end.to_h

    stats[:total] = stats.values.flatten.group_by { |v| v[:timestamp] }.map do |timestamp, day_stats|
      {
        timestamp: timestamp,
        markets_created: day_stats.sum { |v| v[:markets_created] },
        volume_eur: day_stats.sum { |v| v[:volume_eur] },
        tvl_volume_eur: day_stats.sum { |v| v[:tvl_volume_eur] },
        liquidity_eur: day_stats.sum { |v| v[:liquidity_eur] },
        tvl_liquidity_eur: day_stats.sum { |v| v[:tvl_liquidity_eur] },
        fees_eur: day_stats.sum { |v| v[:fees_eur] },
        users: day_stats.sum { |v| v[:users] },
        transactions: day_stats.sum { |v| v[:transactions] }
      }
    end

    stats
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
