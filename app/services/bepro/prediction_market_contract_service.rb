module Bepro
  class PredictionMarketContractService < SmartContractService
    include BigNumberHelper

    ACTIONS_MAPPING = {
      0 => 'buy',
      1 => 'sell',
      2 => 'add_liquidity',
      3 => 'remove_liquidity',
      4 => 'claim_winnings',
      5 => 'claim_liquidity',
      6 => 'claim_fees',
    }.freeze

    STATES_MAPPING = {
      0 => 'open',
      1 => 'closed',
      2 => 'resolved',
    }

    def initialize(url: nil, contract_address: nil)
      super(contract_name: 'predictionMarket', contract_address: Config.ethereum.prediction_market_contract_address)
    end

    def get_all_market_ids
      call(method: 'getMarkets')
    end

    def get_all_markets
      market_ids = call(method: 'getMarkets')
      market_ids.map { |market_id| get_market(market_id) }
    end

    def get_market(market_id)
      market_data = call(method: 'getMarketData', args: market_id)
      market_alt_data = call(method: 'getMarketAltData', args: market_id)

      # formatting question_id
      question_id = market_alt_data[1]

      outcomes = get_market_outcomes(market_id)

      # fetching market details from event
      events = get_events(event_name: 'MarketCreated', filter: { marketId: market_id.to_s })

      raise "Market #{market_id}: MarketCreated event not found" if events.blank?
      raise "Market #{market_id}: MarketCreated event count: #{events.count} != 1" if events.count != 1

      # decoding question from event. format from realitio
      # https://reality.eth.link/app/docs/html/contracts.html#how-questions-are-structured
      question = events[0]['returnValues']['question'].split("\u241f")
      title = question[0]
      category = question[2].split(';').first
      subcategory = question[2].split(';').last
      outcome_titles = JSON.parse("[#{question[1]}]")
      outcomes.each_with_index { |outcome, i| outcome[:title] = outcome_titles[i] }
      image_hash = events[0]['returnValues']['image']

      {
        id: market_id,
        title: title,
        category: category,
        subcategory: subcategory,
        image_hash: image_hash,
        state: STATES_MAPPING[market_data[0].to_i],
        expires_at: Time.at(market_data[1].to_i).to_datetime,
        liquidity: from_big_number_to_float(market_data[2]),
        fee: from_big_number_to_float(market_alt_data[0]),
        shares: from_big_number_to_float(market_data[4]),
        resolved_outcome_id: market_data[5].to_i,
        question_id: question_id,
        outcomes: outcomes
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
          shares: from_big_number_to_float(outcome_data[1]),
        }
      end
    end

    def get_market_prices(market_id)
      market_prices = call(method: 'getMarketPrices', args: market_id)

      {
        liquidity_price: from_big_number_to_float(market_prices[0]),
        outcome_shares: {
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
        liquidity_shares: from_big_number_to_float(user_data[0]),
        outcome_shares: {
          0 => from_big_number_to_float(user_data[1]),
          1 => from_big_number_to_float(user_data[2])
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
      events.sum { |event| event['returnValues']['value'] }
    end

    def get_price_events(market_id)
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
          value: from_big_number_to_float(event['returnValues']['value']),
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
          shares: from_big_number_to_float(event['returnValues']['shares']),
          value: from_big_number_to_float(event['returnValues']['value']),
          timestamp: event['returnValues']['timestamp'].to_i,
        }
      end
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

    def create_market(name, outcome_1_name, outcome_2_name, duration: (DateTime.now + 1.day).to_i, oracle_address: Config.ethereum.oracle_address, value: 1e17.to_i)
      function_name = 'createMarket'
      function_args = [
        name,
        duration,
        oracle_address,
        outcome_1_name,
        outcome_2_name
      ]

      call_payable_function(function_name, function_args, value, Config.ethereum.oracle_address)
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
  end
end
