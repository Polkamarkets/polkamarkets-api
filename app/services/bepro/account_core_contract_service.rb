module Bepro
  class AccountCoreContractService < SmartContractService

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'accountCore',
        contract_address: contract_address,
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def get_admins()
      call(method: 'getAllAdmins')
    end
  end
end
