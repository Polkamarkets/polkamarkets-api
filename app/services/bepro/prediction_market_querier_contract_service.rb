module Bepro
  class PredictionMarketQuerierContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      @version = Rails.application.config_for(:ethereum).dig(:prediction_market_contract_version) || 3

      super(
        network_id: network_id,
        contract_name: "predictionMarketV#{@version}Querier",
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_querier_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :prediction_market_querier_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def get_market_users_data(market_id, users)
      call(method: 'getMarketUsersData', args: [market_id, users.to_json])
    end
  end
end
