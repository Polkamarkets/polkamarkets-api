module Bepro
  class PredictionMarketContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    attr_accessor :version

    ACTIONS_MAPPING = {
      0 => 'buy',
      1 => 'sell',
      2 => 'add_liquidity',
      3 => 'remove_liquidity',
      4 => 'claim_winnings',
      5 => 'claim_liquidity',
      6 => 'claim_fees',
      7 => 'claim_voided',
    }.freeze

    STATES_MAPPING = {
      0 => 'open',
      1 => 'closed',
      2 => 'resolved',
    }

    DELIMITER = "\u241f"

    def initialize(network_id: nil, api_url: nil, contract_address: nil, version: 2)
      @version = version

      super(
        network_id: network_id,
        contract_name: version == 2 ? 'predictionMarketV2' : 'predictionMarket',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :prediction_market_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def get_all_market_ids
      call(method: 'getMarkets')
    end

    def get_fee
      # TODO: remove
      0.02
    end

    def get_market_count
      response = call(method: 'marketIndex')
      response.is_a?(Array) ? response.join.to_i : response.to_i
    end

    def get_all_markets
      market_ids = call(method: 'getMarkets')
      market_ids.map { |market_id| get_market(market_id) }
    end

    def get_market(market_id)
      market_data = call(method: 'getMarketData', args: market_id)
      market_alt_data = call(method: 'getMarketAltData', args: market_id)
      is_market_voided = call(method: 'isMarketVoided', args: market_id)

      # formatting question_id
      question_id = market_alt_data[1]

      outcomes = get_market_outcomes(market_id)

      # fetching market details from event
      events = get_events(event_name: 'MarketCreated')
      # not using marketId filter for cache query hit purposes
      events.select! { |event| event['returnValues']['marketId'] == market_id.to_s }

      raise "Market #{market_id}: MarketCreated event not found" if events.blank?
      raise "Market #{market_id}: MarketCreated event count: #{events.count} != 1" if events.count != 1

      # decoding question from event. format from realitio
      # https://reality.eth.link/app/docs/html/contracts.html#how-questions-are-structured
      question = events[0]['returnValues']['question'].split(DELIMITER)
      title = question[0].split(';').first
      description = question[0].split(';')[1..-1].join(';')
      category = question[-1].split(';').first
      subcategory = question[-1].split(';').second
      resolution_source = question[-1].split(';')[2..-1].join(';') if question[-1].split(';')[2..-1].present?
      outcome_titles = JSON.parse("[#{question[-2]}]")
      outcomes.each_with_index { |outcome, i| outcome[:title] = outcome_titles[i] }
      image_hash = events[0]['returnValues']['image'].split(DELIMITER)[0]
      outcomes_image_hashes = events[0]['returnValues']['image'].split(DELIMITER)[1].presence&.split(',')
      # making sure outcomes_image_hashes length is correct
      outcomes_image_hashes = outcomes_image_hashes.present? && outcomes_image_hashes.count == outcomes.count ?
        outcomes_image_hashes : []
      token_address = market_alt_data[3]

      {
        id: market_id,
        title: title,
        description: description,
        category: category,
        subcategory: subcategory,
        resolution_source: resolution_source.presence || nil,
        image_hash: image_hash,
        state: STATES_MAPPING[market_data[0].to_i],
        expires_at: Time.at(market_data[1].to_i).to_datetime,
        liquidity: from_big_number_to_float(market_data[2], network_market_erc20_decimals(network_id, market_id)),
        fee: from_big_number_to_float(market_alt_data[0]),
        treasury_fee: from_big_number_to_float(market_alt_data[4]),
        treasury: market_alt_data[5],
        shares: from_big_number_to_float(market_data[4], network_market_erc20_decimals(network_id, market_id)),
        resolved_outcome_id: market_data[5].to_i,
        question_id: question_id,
        voided: is_market_voided,
        outcomes: outcomes,
        outcomes_image_hashes: outcomes_image_hashes,
        token_address: token_address,
      }
    end

    def get_market_outcomes(market_id)
      # currently only binary

      outcome_ids = call(method: 'getMarketOutcomeIds', args: market_id)
      outcome_ids.map do |outcome_id|
        outcome_data = call(method: 'getMarketOutcomeData', args: [market_id, outcome_id])

        {
          id: outcome_id.to_i,
          title: '', # TODO remove; deprecated
          price: from_big_number_to_float(outcome_data[0]),
          shares: from_big_number_to_float(outcome_data[1], network_market_erc20_decimals(network_id, market_id)),
        }
      end
    end

    def get_market_prices(market_id)
      market_prices = call(method: 'getMarketPrices', args: market_id)

      {
        liquidity_price: from_big_number_to_float(market_prices[0]),
        outcome_shares:
          version == 2 ?
            market_prices[1].each_with_index.map { |price, i| from_big_number_to_float(price) } :
            {
              0 => from_big_number_to_float(market_prices[1]),
              1 => from_big_number_to_float(market_prices[2])
            }
      }
    end

    def get_user_market_shares(market_id, address)
      user_data = call(method: 'getUserMarketShares', args: [market_id, address])

      # TODO: improve this
      {
        market_id: market_id,
        address: address,
        liquidity_shares: from_big_number_to_float(user_data[0], network_market_erc20_decimals(network_id, market_id)),
        outcome_shares:
          version == 2 ?
            user_data[1].each_with_index.map do |share, i|
              [i, from_big_number_to_float(share, network_market_erc20_decimals(network_id, market_id))]
            end.to_h :
            {
              0 => from_big_number_to_float(user_data[1], network_market_erc20_decimals(network_id, market_id)),
              1 => from_big_number_to_float(user_data[2], network_market_erc20_decimals(network_id, market_id))
            }
      }
    end

    def get_user_liquidity_fees_earned(address)
      events = get_events(
        event_name: 'MarketActionTx',
        filter: {
          user: address,
          action: 6
        }
      )

      events.map do |event|
        {
          market_id: event['returnValues']['marketId'].to_i,
          value: from_big_number_to_float(
            event['returnValues']['value'],
            network_market_erc20_decimals(network_id, event['returnValues']['marketId'].to_i)
          ),
          timestamp: event['returnValues']['timestamp'].to_i,
        }
      end
    end

    def translate_market_outcome_shares_to_prices(shares_events, market_id)
      # V2 events are shares only, prices have to be computed
      events = []

      shares_events.each do |event|
        outcome_shares = event['returnValues']['outcomeShares'].map do |share|
          from_big_number_to_float(share, network_market_erc20_decimals(network_id, market_id))
        end
        # outcome price = 1 / (sum(outcome shares / every outcome shares))
        outcome_prices = outcome_shares.map { |share| 1 / (outcome_shares.sum { |s| share / s.to_f }) }
        outcome_prices.each_with_index do |price, i|
          events << {
            market_id: event['returnValues']['marketId'].to_i,
            outcome_id: i,
            price: price,
            timestamp: event['returnValues']['timestamp'].to_i,
          }
        end
      end

      events
    end

    def get_price_events(market_id)
      if version == 2
        events = get_events(
          event_name: 'MarketOutcomeShares',
          filter: {
            marketId: market_id.to_s,
          }
        )

        translate_market_outcome_shares_to_prices(events, market_id)
      else
        events = get_events(
          event_name: 'MarketOutcomePrice',
          filter: {
            marketId: market_id.to_s,
          }
        )

        events.map do |event|
          {
            market_id: event['returnValues']['marketId'].to_i,
            outcome_id: event['returnValues']['outcomeId'].to_i,
            price: from_big_number_to_float(event['returnValues']['value']),
            timestamp: event['returnValues']['timestamp'].to_i,
          }
        end
      end
    end

    def get_liquidity_events(market_id = nil)
      events = get_events(
        event_name: 'MarketLiquidity',
        filter: {
          marketId: market_id.to_s,
        }
      )

      events.map do |event|
        {
          market_id: event['returnValues']['marketId'].to_i,
          value: from_big_number_to_float(
            event['returnValues']['value'],
            network_market_erc20_decimals(network_id, event['returnValues']['marketId'].to_i)
          ),
          price: from_big_number_to_float(event['returnValues']['price']),
          timestamp: event['returnValues']['timestamp'].to_i,
        }
      end
    end

    def get_action_events(market_id: nil, address: nil)
      events = get_events(
        event_name: 'MarketActionTx',
        filter: {
          marketId: market_id.to_s,
          user: address,
        }
      )

      events.map do |event|
        {
          address: event['returnValues']['user'],
          action: ACTIONS_MAPPING[event['returnValues']['action'].to_i],
          market_id: event['returnValues']['marketId'].to_i,
          outcome_id: event['returnValues']['outcomeId'].to_i,
          shares: from_big_number_to_float(
            event['returnValues']['shares'],
            network_market_erc20_decimals(network_id, event['returnValues']['marketId'].to_i)
          ),
          value: from_big_number_to_float(
            event['returnValues']['value'],
            network_market_erc20_decimals(network_id, event['returnValues']['marketId'].to_i)
          ),
          timestamp: event['returnValues']['timestamp'].to_i,
          tx_id: event['transactionHash'],
          block_number: event['blockNumber']
        }
      end
    end

    def refresh_action_events(market_id: nil, address: nil)
      refresh_events(
        event_name: 'MarketActionTx',
        filter: {
          marketId: market_id.to_s,
          user: address,
        }
      )
    end

    def get_market_resolved_at(market_id)
      # args: (address) user, (uint) marketId,
      args = [nil, market_id]

      events = get_events(
        event_name: 'MarketResolved',
        filter: {
          marketId: market_id.to_s,
        }
      )
      # market still not resolved / no valid resolution event
      return -1 if events.count != 1

      events[0]['returnValues']['timestamp'].to_i
    end

    def get_market_resolved_events()
      events = get_events(
        event_name: 'MarketResolved',
      )


      events.map do |event|
        {
          user: event['returnValues']['user'],
          market_id: event['returnValues']['market_id'],
          outcome_id: event['returnValues']['market_id'],
          timestamp: event['returnValues']['timestamp'].to_i,
          block_number: event['blockNumber']
        }
      end
    end

    def stats(market_id: nil)
      actions = get_action_events(market_id: market_id)

      {
        users: actions.map { |v| v[:address] }.uniq.count,
        buy_count: actions.select { |v| v[:action] == 'buy' }.count,
        buy_total: actions.select { |v| v[:action] == 'buy' }.sum { |v| v[:value] },
        sell_count: actions.select { |v| v[:action] == 'sell' }.count,
        sell_total: actions.select { |v| v[:action] == 'sell' }.sum { |v| v[:value] },
        add_liquidity_count: actions.select { |v| v[:action] == 'add_liquidity' }.count,
        add_liquidity_total: actions.select { |v| v[:action] == 'add_liquidity' }.sum { |v| v[:value] },
        claim_winnings_count: actions.select { |v| v[:action] == 'claim_winnings' }.count,
        claim_winnings_total: actions.select { |v| v[:action] == 'claim_winnings' }.sum { |v| v[:value] }
      }
    end

    def weth_address
      call(method: 'WETH')
    end
  end
end
