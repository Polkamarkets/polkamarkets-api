module Ethereum
  class RealitioErc20ContractService < SmartContractService
    include BigNumberHelper

    def initialize(url: nil, contract_address: nil)
      @contract_name = 'RealitioERC20'
      @contract_address = Config.ethereum.realitio_contract_address

      super(url: url, contract_address: contract_address)
    end

    def get_question(question_id)
      # receiving question_id in bytes32 format (with 0x prefix), converting to rails format
      question_id_b32 = [question_id[2..-1]].pack('H*')

      question_data = contract.call.questions(question_id_b32)
      question_is_finalized = contract.call.is_finalized(question_id_b32)

      best_answer = encoder.ensure_prefix(question_data[7].unpack('H*').first)
      # hotfix on smart contract return of 0 value
      best_answer = '0x0000000000000000000000000000000000000000000000000000000000000000' if best_answer == '0x'

      {
        id: question_id,
        bond: from_big_number_to_float(question_data[9]),
        best_answer: best_answer,
        is_finalized: question_is_finalized,
        finalize_ts: question_data[4]
      }
    end
  end
end
