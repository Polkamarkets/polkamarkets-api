module Ethereum
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
      @contract_name = 'PredictionMarket'
      @contract_address = Config.ethereum.contract_address

      super(url: url, contract_address: contract_address)
    end

    def get_all_market_ids
      contract.call.get_markets
    end

    def get_all_markets
      market_ids = contract.call.get_markets
      market_ids.map { |market_id| get_market(market_id) }
    end

    def get_market(market_id)
      market_data = contract.call.get_market_data(market_id)
      market_alt_data = contract.call.get_market_alt_data(market_id)
      # formatting question_id
      question_id = encoder.ensure_prefix(market_alt_data[2].to_s(16).rjust(64, '0'))

      outcomes = get_market_outcomes(market_id)
      # legacy markets have title straight from the market struct
      title = market_data[0]
      category = nil
      subcategory = nil

      if title.blank?
        # new contract, fetching market details from event
        events = get_events('MarketCreated', [nil, market_id])

        if events.present?
          # decoding question from event. format from realitio
          # https://reality.eth.link/app/docs/html/contracts.html#how-questions-are-structured
          question = events[0][:args][1].split("\u241f")
          title = question[0]
          category = question[2].split(';').first
          subcategory = question[2].split(';').last
          outcome_titles = JSON.parse("[#{question[1]}]")
          outcomes.each_with_index { |outcome, i| outcome[:title] = outcome_titles[i] }
          image_hash = events[0][:args][2]
        end
      end

      {
        id: market_id,
        title: title,
        category: category,
        subcategory: subcategory,
        image_hash: image_hash,
        state: STATES_MAPPING[market_data[1]],
        expires_at: Time.at(market_data[2]).to_datetime,
        liquidity: from_big_number_to_float(market_data[3]),
        fee: from_big_number_to_float(market_alt_data[0]),
        shares: from_big_number_to_float(market_data[5]),
        resolved_outcome_id: market_data[6],
        question_id: question_id,
        outcomes: outcomes
      }
    end

    def get_market_outcomes(market_id)
      # currently only binary
      outcome_ids = contract.call.get_market_outcome_ids(market_id)
      outcome_ids.map do |outcome_id|
        outcome_data = contract.call.get_market_outcome_data(market_id, outcome_id)

        {
          id: outcome_id,
          title: outcome_data[0],
          price: from_big_number_to_float(outcome_data[1]),
          shares: from_big_number_to_float(outcome_data[2]),
        }
      end
    end

    def get_market_prices(market_id)
      market_prices = contract.call.get_market_prices(market_id)

      {
        liquidity_price: from_big_number_to_float(market_prices[0]),
        outcome_shares: {
          0 => from_big_number_to_float(market_prices[1]),
          1 => from_big_number_to_float(market_prices[2])
        }
      }
    end

    def get_user_market_shares(market_id, address)
      user_data = contract.call.get_user_market_shares(market_id, address)

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
      # args: (address) participant, (uint) action, (uint) marketId,
      args = [address, 6, nil]

      events = get_events('ParticipantAction', args)
      events.sum { |event| from_big_number_to_float(event[:args][2]) }
    end

    def get_price_events(market_id)
      events = get_events('MarketOutcomePrice', [market_id])

      events.map do |event|
        {
          market_id: event[:topics][1].hex,
          outcome_id: event[:topics][2].hex,
          price: from_big_number_to_float(event[:args][0]),
          timestamp: event[:args][1],
        }
      end
    end

    def get_liquidity_events(market_id = nil)
      events = get_events('MarketLiquidity', [market_id])

      events.map do |event|
        {
          market_id: event[:topics][1].hex,
          value: from_big_number_to_float(event[:args][0]),
          price: from_big_number_to_float(event[:args][1]),
          timestamp: event[:args][2],
        }
      end
    end

    def get_action_events(market_id: nil, address: nil)
      # args: (address) participant, (uint) action, (uint) marketId,
      args = [address, nil, market_id]

      events = get_events('ParticipantAction', args)

      events.map do |event|
        {
          address: "0x" + event[:topics][1].last(40),
          action: ACTIONS_MAPPING[event[:topics][2].hex],
          market_id: event[:topics][3].hex,
          outcome_id: event[:args][0],
          shares: from_big_number_to_float(event[:args][1]),
          value: from_big_number_to_float(event[:args][2]),
          timestamp: event[:args][3],
        }
      end
    end

    def get_market_resolved_at(market_id)
      # args: (address) participant, (uint) marketId,
      args = [nil, market_id]

      events = get_events('MarketResolved', args)
      # market still not resolved / no valid resolution event
      return -1 if events.count != 1

      events[0][:args][1]
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
