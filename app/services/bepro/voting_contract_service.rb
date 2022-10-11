module Bepro
  class VotingContractService < SmartContractService
    include BigNumberHelper

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

    def get_vote(market_id)
      vote_data = call(method: 'getItemVotes', args: market_id)

      {
        upvotes: vote_data[0],
        downvotes: vote_data[1]
      }
    end
  end
end
