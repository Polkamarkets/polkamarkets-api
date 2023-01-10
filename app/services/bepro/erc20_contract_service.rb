module Bepro
  class Erc20ContractService < SmartContractService
    include BigNumberHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        contract_name: 'erc20',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :erc20_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :erc20_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def balance_of(user)
      # if contract is not deployed, returning 0 as default
      return 0 if contract_address.blank?

      from_big_number_to_float(call(method: 'balanceOf', args: user))
    end
  end
end
