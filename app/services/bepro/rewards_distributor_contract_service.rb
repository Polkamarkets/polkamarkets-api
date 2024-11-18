module Bepro
  class RewardsDistributorContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: "rewardsDistributor",
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :rewards_distributor_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url),
      )
    end

    def add_claim_amount(user_address, amount, preferred_token)
      execute(
        method: 'increaseUserClaimAmount',
        args: [
          user_address,
          from_float_to_big_number(amount, 18).to_s,
          preferred_token,
        ])
    end

    def set_claim_amount(user_address, amount, preferred_token)
      execute(
        method: 'setUserClaimAmount',
        args: [
          user_address,
          from_float_to_big_number(amount, 18).to_s,
          preferred_token,
        ])
    end

    def get_claimed_events(user_address)
      events = get_events(event_name: 'TokensClaimed', filter: { user: user_address })

      events.map do |event|
        {
          user: event['returnValues']['user'],
          token: event['returnValues']['token'],
          receiver: event['returnValues']['receiver'],
          amount: from_big_number_to_float(event['returnValues']['amount'], 18),
          transaction_hash: event['transactionHash']
        }
      end

    end
  end
end
