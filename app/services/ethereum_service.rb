class EthereumService
  include BigNumberHelper

  attr_accessor :client, :contract

  def initialize
    @client = Ethereum::HttpClient.new(Rails.application.secrets.ethereum_url)
    abi = JSON.parse(File.read('app/contracts/PredictionMarket.json'))['abi']
    @contract = Ethereum::Contract.create(name: "PredictionMarket", address: Rails.application.secrets.ethereum_contract_address, abi: abi, client: client)
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
    outcomes = get_market_outcomes(market_id)

    {
      id: market_id,
      name: market_data[0],
      state: market_data[1],
      resolved_at: Time.at(market_data[2]).to_datetime,
      liquidity: from_big_number_to_float(market_data[3]),
      shares: from_big_number_to_float(market_data[4]),
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
        name: outcome_data[0],
        price: from_big_number_to_float(outcome_data[1]),
      }
    end
  end

  def get_user_market_shares(market_id, address)
    user_data = contract.call.get_user_market_shares(market_id, address)

    # TODO: improve this
    {
      liquidity_shares: from_big_number_to_float(user_data[0]),
      outcome_shares: {
        0 => from_big_number_to_float(user_data[1]),
        1 => from_big_number_to_float(user_data[2])
      }
    }
  end
end
