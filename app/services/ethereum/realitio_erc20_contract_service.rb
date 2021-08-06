module Ethereum
  class RealitioErc20ContractService < SmartContractService
    include BigNumberHelper

    def initialize(url: nil, contract_address: nil)
      @contract_name = 'RealitioERC20'
      @contract_address = Config.ethereum.realitio_contract_address

      super(url: url, contract_address: contract_address)
    end
  end
end
