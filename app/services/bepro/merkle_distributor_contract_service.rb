module Bepro
  class MerkleDistributorContractService < SmartContractService

    def initialize(network_id: nil, api_url: nil, contract_address: nill)
      super(
        network_id: network_id,
        contract_name: 'merkleDistributor',
        contract_address:
          contract_address,
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"rewards_network_#{network_id}", :bepro_api_url),
      )
    end

    def is_claimed(index)
      call(method: 'isClaimed', args: index)
    end

    def erc20_address
      call(method: 'token')
    end

    def erc20_decimals
      erc20TokenAddress = erc20_address()

      Bepro::Erc20ContractService.new(network_id: @network_id, api_url: @api_url, contract_address: erc20TokenAddress).decimals
    end

  end
end
