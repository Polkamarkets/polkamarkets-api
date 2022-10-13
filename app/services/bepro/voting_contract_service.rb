module Bepro
  class VotingContractService < SmartContractService
    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        contract_name: 'voting',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :voting_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :voting_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def get_votes(market_id)
      # if contract is not deployed, returning 0 data structure as default
      return { up: 0, down: 0 } if contract_address.blank?

      vote_data = call(method: 'getItemVotes', args: market_id)

      {
        up: vote_data[0].to_i,
        down: vote_data[1].to_i
      }
    end
  end
end
