module Ethereum
  class Erc20ContractService < SmartContractService
    include BigNumberHelper

    def initialize(url: nil, contract_address: nil)
      @contract_name = 'ERC20'
      @contract_address = Config.ethereum.erc20_contract_address

      super(url: url, contract_address: contract_address)
    end

    def transfer(recipient, amount)
      call_payable_function(
        'transfer',
        [
          recipient,
          from_integer_to_big_number(amount)
        ],
        0,
        Config.ethereum.oracle_address
      )
    end
  end
end
