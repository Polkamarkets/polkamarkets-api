module Bepro
  class PredictionMarketControllerContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      @version = Rails.application.config_for(:ethereum).dig(:prediction_market_contract_version) || 3

      @token_amount_to_claim = Rails.application.config_for(:ethereum).token_amount_to_claim > 0 ?
        Rails.application.config_for(:ethereum).token_amount_to_claim : 1000
      @token_to_answer = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :erc20_contract_address)

      super(
        network_id: network_id,
        contract_name: "predictionMarketV#{@version}Controller",
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_controller_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :prediction_market_controller_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def create_land(name, symbol)
      execute(
        method: 'createLand',
        args: [
          name,
          symbol,
          from_integer_to_big_number(@token_amount_to_claim, 18).to_s,
          @token_to_answer
        ])
    end

    def set_land_everyone_can_create_markets(token_address, everyone_can_create_markets)
      execute(
        method: 'setLandEveryoneCanCreateMarkets',
        args: [
          token_address,
          everyone_can_create_markets
      ])
    end

    def add_admin_to_land(token_address, user_address)
      execute(
        method: 'addAdminToLand',
        args: [
          token_address, user_address
        ])
    end

    def remove_admin_from_land(token_address, user_address)
      execute(
        method: 'removeAdminFromLand',
        args: [
          token_address, user_address
        ])
    end
  end
end
