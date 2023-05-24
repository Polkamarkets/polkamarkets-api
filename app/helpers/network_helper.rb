
module NetworkHelper
  def network_name(network_id)
    network = Rails.application.config_for(:networks).find { |name, id| id == network_id }
    network ? network.first.to_s.capitalize : 'Unknown'
  end

  def network_actions(network_id)
    Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
    end
  end

  def network_bonds(network_id)
    Rails.cache.fetch("api:bonds:#{network_id}", expires_in: 24.hours) do
      Bepro::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
    end
  end

  def network_votes(network_id)
    Rails.cache.fetch("api:votes:#{network_id}", expires_in: 24.hours) do
      Bepro::VotingContractService.new(network_id: network_id).get_voting_events
    end
  end

  def network_erc20_balance(network_id, address)
    Rails.cache.fetch("api:erc20_balances:#{network_id}:#{address}", expires_in: 24.hours) do
      Bepro::Erc20ContractService.new(network_id: network_id).balance_of(address)
    end
  end

  def network_weth_address(network_id)
    Rails.cache.fetch("api:weth_address:#{network_id}", expires_in: 24.hours) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).weth_address
    end
  end

  def network_market_erc20_decimals(network_id, market_id)
    Rails.cache.fetch("api:erc20_decimals:#{network_id}:#{market_id}") do
      market_alt_data =
        Bepro::PredictionMarketContractService.new(network_id: network_id)
          .call(method: 'getMarketAltData', args: market_id)
      token_address = market_alt_data[3]

      Bepro::Erc20ContractService.new(network_id: network_id, contract_address: token_address).decimals
    end
  end

  def network_realitio_decimals(network_id)
    Rails.cache.fetch("api:realitio_decimals:#{network_id}") do
      token_address = Bepro::RealitioErc20ContractService.new(network_id: network_id).token
      Bepro::Erc20ContractService.new(network_id: network_id, contract_address: token_address).decimals
    end
  end
end
