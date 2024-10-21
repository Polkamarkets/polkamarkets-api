module Bepro
  class PredictionMarketManagerContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      @version = Rails.application.config_for(:ethereum).dig(:prediction_market_contract_version) || 3

      super(
        network_id: network_id,
        contract_name: "predictionMarketV#{@version}Manager",
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_manager_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :prediction_market_manager_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def get_land_data(token_address)
      land_data = call(method: 'lands', args: [token_address])

      {
        address: land_data[0],
        active: land_data[1],
        lock_amount: from_big_number_to_float(land_data[2]),
        lock_user: land_data[3],
        realitio_address: land_data[4],
      }
    end

    def get_land_admins(token_address)
      return [] if contract_address.blank?

      land_created_events = get_events(event_name: 'LandCreated', filter: { token: token_address })
      admin_added_events = get_events(event_name: 'LandAdminAdded', filter: { token: token_address })
      admin_removed_events = get_events(event_name: 'LandAdminRemoved', filter: { token: token_address })

      admins = []

      land_created_events.each do |event|
        admin = event['returnValues']['user']

        next if admin_removed_events.any? { |e| e['returnValues']['admin'] == admin && e['blockNumber'] > event['blockNumber'] }

        admins << admin
      end

      admin_added_events.each do |event|
        admin = event['returnValues']['admin']

        next if admin_removed_events.any? { |e| e['returnValues']['admin'] == admin && e['blockNumber'] > event['blockNumber'] }

        admins << admin
      end

      admins.uniq
    end
  end
end
