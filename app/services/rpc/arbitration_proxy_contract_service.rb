module Rpc
  class ArbitrationProxyContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'arbitrationProxy',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :arbitration_proxy_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :arbitration_proxy_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :rpc_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :rpc_api_url),
      )
    end

    def arbitration_requests_rejected(question_id)
      events = get_events(event_name: 'RequestRejected').select do |event|
        event['returnValues']['_questionID'] == question_id
      end

      events.map do |event|
        {
          question_id: event['returnValues']['_questionID'],
          requester: event['returnValues']['_requester'],
          max_previous: from_big_number_to_float(event['returnValues']['_maxPrevious']),
          reason: event['returnValues']['_reason'],
        }
      end
    end
  end
end
