
module NetworkHelper
  def network_name(network_id)
    network = Rails.application.config_for(:networks).find { |name, id| id == network_id }
    network ? network.first.to_s.capitalize : 'Unknown'
  end

  def network_actions(network_id)
    Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
      Rpc::PredictionMarketContractService.new(network_id: network_id).get_action_events
    end
  end

  def network_bonds(network_id)
    Rails.cache.fetch("api:bonds:#{network_id}", expires_in: 24.hours) do
      Rpc::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
    end
  end

  def network_votes(network_id)
    Rails.cache.fetch("api:votes:#{network_id}", expires_in: 24.hours) do
      Rpc::VotingContractService.new(network_id: network_id).get_voting_events
    end
  end

  def network_erc20_balance(network_id, address)
    Rails.cache.fetch("api:erc20_balances:#{network_id}:#{address}", expires_in: 24.hours) do
      Rpc::Erc20ContractService.new(network_id: network_id).balance_of(address)
    end
  end

  def network_weth_address(network_id)
    Rails.cache.fetch("api:weth_address:#{network_id}", expires_in: 24.hours) do
      Rpc::PredictionMarketContractService.new(network_id: network_id).weth_address
    end
  end

  def network_market_erc20_decimals(network_id, market_id)
    Rails.cache.fetch("api:erc20_decimals:#{network_id}:#{market_id}") do
      market_alt_data =
        Rpc::PredictionMarketContractService.new(network_id: network_id)
          .call(method: 'getMarketAltData', args: market_id)
      token_address = market_alt_data[3]

      Rpc::Erc20ContractService.new(network_id: network_id, contract_address: token_address).decimals
    end
  end

  def network_realitio_decimals(network_id)
    Rails.cache.fetch("api:realitio_decimals:#{network_id}") do
      token_address = Rpc::RealitioErc20ContractService.new(network_id: network_id).token
      Rpc::Erc20ContractService.new(network_id: network_id, contract_address: token_address).decimals
    end
  end

  def network_burn_actions(network_id)
    return [] unless Rails.application.config_for(:ethereum).fantasy_enabled

    Rails.cache.fetch("api:burn_actions:#{network_id}", expires_in: 24.hours) do
      Rpc::Erc20ContractService.new(network_id: network_id).burn_events
    end
  end

  def network_mint_actions(network_id)
    return [] unless Rails.application.config_for(:ethereum).fantasy_enabled

    Rails.cache.fetch("api:mint_actions:#{network_id}", expires_in: 24.hours) do
      Rpc::Erc20ContractService.new(network_id: network_id).mint_events
    end
  end

  def network_markets_resolved(network_id)
    Rails.cache.fetch("api:markets_resolved:#{network_id}", expires_in: 24.hours) do
      Rpc::PredictionMarketContractService.new(network_id: network_id).get_market_resolved_events
    end
  end
end
