module Rpc
  class RealitioErc20ContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'realitio',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :realitio_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :realitio_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :rpc_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :rpc_api_url),
      )
    end

    def token
      call(method: 'token')
    end

    def get_question(question_id)
      question_data = call(method: 'questions', args: question_id)
      question_is_finalized = call(method: 'isFinalized', args: question_id)

      question_is_claimed = question_is_finalized && question_data[8].hex == 0
      best_answer = question_data[7]

      {
        id: question_id,
        bond: from_big_number_to_float(question_data[9], network_realitio_decimals(network_id)),
        best_answer: best_answer,
        is_finalized: question_is_finalized,
        arbitrator: question_data[1],
        is_pending_arbitration: question_data[5],
        is_claimed: question_is_claimed,
        finalize_ts: question_data[4].to_i
      }
    end

    def get_bond_events(question_id: nil, user: nil)
      events = get_events(
        event_name: 'LogNewAnswer',
        filter: {
          question_id: question_id,
          user: user,
        }
      )

      events.map do |event|
        {
          user: event['returnValues']['user'],
          question_id: event['returnValues']['question_id'],
          answer: event['returnValues']['answer'],
          value: from_big_number_to_float(event['returnValues']['bond'], network_realitio_decimals(network_id)),
          timestamp: event['returnValues']['ts'].to_i,
        }
      end
    end
  end
end
