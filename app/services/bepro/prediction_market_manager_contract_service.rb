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

    def get_land_admins(token_address)
      return [] if contract_address.blank?

      admin_added_events = get_events(event_name: 'LandAdminAdded', filter: { token: token_address })
      admin_removed_events = get_events(event_name: 'LandAdminRemoved', filter: { token: token_address })

      admins = []

      admin_added_events.each do |event|
        admin = event['returnValues']['admin']

        next if admin_removed_events.any? { |e| e['returnValues']['admin'] == admin && e['blockNumber'] > event['blockNumber'] }

        admins << admin
      end

      admins.uniq
    end
  end
end
