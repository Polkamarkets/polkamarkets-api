module Bepro
  class MerkleDistributorContractService < SmartContractService

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'merkleDistributor',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"rewards_network_#{network_id}", :reward_merkle_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"rewards_network_#{network_id}", :bepro_api_url),
      )
    end

    def is_claimed(index)
      call(method: 'isClaimed', args: index)
    end
  end
end
