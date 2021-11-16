module Bepro
  class RealitioErc20ContractService < SmartContractService
    include BigNumberHelper

    def initialize(url: nil, contract_address: nil)
      super(contract_name: 'realitio', contract_address: Rails.application.config_for(:ethereum).realitio_contract_address)
    end

    def get_question(question_id)
      question_data = call(method: 'questions', args: question_id)
      question_is_finalized = call(method: 'isFinalized', args: question_id)

      question_is_claimed = question_is_finalized && question_data[8].hex == 0
      best_answer = question_data[7]

      {
        id: question_id,
        bond: from_big_number_to_float(question_data[9]),
        best_answer: best_answer,
        is_finalized: question_is_finalized,
        is_claimed: question_is_claimed,
        finalize_ts: question_data[4].to_i
      }
    end
  end
end
