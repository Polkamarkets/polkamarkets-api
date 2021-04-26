module Ethereum
  class PredictionMarketContractService < SmartContractService
    include BigNumberHelper

    ACTIONS_MAPPING = {
      0 => 'buy',
      1 => 'sell',
      2 => 'add_liquidity',
      3 => 'remove_liquidity',
    }.freeze

    STATES_MAPPING = {
      0 => 'open',
      1 => 'closed',
      2 => 'resolved',
    }

    def get_all_market_ids
      contract.call.get_markets
    end

    def get_all_markets
      market_ids = contract.call.get_markets
      market_ids.map { |market_id| get_market(market_id) }
    end

    def get_market(market_id)
      market_data = contract.call.get_market_data(market_id)
      outcomes = get_market_outcomes(market_id)

      {
        id: market_id,
        title: market_data[0],
        state: STATES_MAPPING[market_data[1]],
        expires_at: Time.at(market_data[2]).to_datetime,
        liquidity: from_big_number_to_float(market_data[3]),
        shares: from_big_number_to_float(market_data[4]),
        resolved_outcome_id: market_data[6],
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

    def get_price_events(market_id = nil)
      events = get_events('MarketOutcomePrice')

      events.map do |event|
        {
          market_id: event[:topics][1].hex,
          outcome_id: event[:topics][2].hex,
          price: from_big_number_to_float(event[:args][0]),
          timestamp: event[:args][1],
        }
      end.select do |event|
        market_id.blank? || event[:market_id] == market_id
      end
    end

    def get_liquidity_events(market_id = nil)
      events = get_events('MarketLiquidity')

      events.map do |event|
        {
          market_id: event[:topics][1].hex,
          value: from_big_number_to_float(event[:args][0]),
          price: from_big_number_to_float(event[:args][1]),
          timestamp: event[:args][2],
        }
      end.select do |event|
        market_id.blank? || event[:market_id] == market_id
      end
    end

    def get_action_events(market_id: nil, address: nil)
      events = get_events('ParticipantAction')

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
      end.select do |event|
        (market_id.blank? || event[:market_id] == market_id) &&
          (address.blank? || event[:address].downcase == address.downcase)
      end
    end

    def create_market(name, outcome_1_name, outcome_2_name, duration: 600, oracle_address: Config.ethereum.oracle_address, value: 1e17.to_i)
      function_name = 'createMarket'
      function_args = [
        name,
        duration,
        oracle_address,
        outcome_1_name,
        outcome_2_name
      ]

      call_payable_function(function_name, function_args, value)
    end
  end
end
