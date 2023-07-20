module Bepro
  class ArbitrationContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'arbitration',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :arbitration_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :arbitration_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def dispute_fee(question_id)
      from_big_number_to_float(call(method: 'getDisputeFee', args: question_id))
    end

    def dispute_id(question_id)
      event = get_events(event_name: 'ArbitrationCreated').find do |event|
        event['returnValues']['_questionID'] == question_id
      end

      event ? event['returnValues']['_disputeID'].to_i : nil
    end

    def arbitration_requests(question_id)
      events = get_events(event_name: 'ArbitrationRequested').select do |event|
        event['returnValues']['_questionID'] == question_id
      end

      events.map do |event|
        {
          question_id: event['returnValues']['_questionID'],
          requester: event['returnValues']['_requester'],
          max_previous: from_big_number_to_float(event['returnValues']['_maxPrevious']),
        }
      end
    end
  end
end
