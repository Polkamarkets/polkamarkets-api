module Bepro
  class RewardContractService < SmartContractService
    ACTIONS_MAPPING = {
      0 => 'lock',
      1 => 'unlock',
    }.freeze

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'reward',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"rewards_network_#{network_id}", :reward_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"rewards_network_#{network_id}", :bepro_api_url),
      )
    end

    def tiers_info
      number_of_tiers = call(method: 'getNumberOfTiers')
      tiers = []

      number_of_tiers.times do |i|
        tier = call(method: 'tiers', args: i)
        tiers << { max_amount: tier[0].to_i, multiplier: tier[1].to_f / 10 }
      end

      tiers
    end

    def get_lock_events(market_id: nil, address: nil)
      # if contract is not deployed, returning [] as default
      return [] if contract_address.blank?

      events = get_events(
        event_name: 'ItemAction',
        filter: {
          itemId: market_id.to_s,
          user: address,
        }
      )


      events.map do |event|
        {
          user: event['returnValues']['user'],
          item_id: event['returnValues']['itemId'],
          action: ACTIONS_MAPPING[event['returnValues']['action'].to_i],
          lock_amount: ACTIONS_MAPPING[event['returnValues']['lock_amount'].to_i],
          timestamp: event['returnValues']['timestamp'].to_i,
          block_number: event['blockNumber']
        }
      end
    end
  end
end
