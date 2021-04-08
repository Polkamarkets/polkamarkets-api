class EthereumService
  attr_accessor :client, :contract

  def initialize
    @client = Ethereum::HttpClient.new(Rails.application.secrets.ethereum_url);
    # TODO read from file in repo
    abi = JSON.parse(File.read('../bepro-js/build/contracts/PredictionMarket.json'))['abi'];
    @contract = Ethereum::Contract.create(name: "PredictionMarket", address: Rails.application.secrets.ethereum_contract_address, abi: abi, client: client);
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
      resolved_at: market_data[2],
      liquidity: market_data[3],
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
        price: outcome_data[1],
      }
    end
  end

  def get_user_market_shares(address)
  end
end
