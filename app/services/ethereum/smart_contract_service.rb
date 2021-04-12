module Ethereum
  class SmartContractService
    include BigNumberHelper

    attr_accessor :client, :contract

    def initialize(url: nil, contract_address: nil)
      # chain parameters can be sent via params and env vars
      url ||= Rails.application.secrets.ethereum_url
      contract_address ||= Rails.application.secrets.ethereum_contract_address

      @client = Ethereum::HttpClient.new(url)
      abi = JSON.parse(File.read('app/contracts/PredictionMarket.json'))['abi']
      @contract = Ethereum::Contract.create(name: "PredictionMarket", address: contract_address, abi: abi, client: client)
    end

    def get_events(event_name, filters = {})
      event_abi = contract.abi.find { |abi| abi['name'] == event_name.to_s }
      event_inputs = event_abi['inputs'].map { |input| OpenStruct.new(input) }

      # indexed and non indexed inputs are store differently
      indexed_inputs = event_inputs.select(&:indexed)
      non_indexed_inputs = event_inputs.reject(&:indexed)

      sig = contract.parent.events.find { |e| e.name.to_s == event_name.to_s }.signature
      topics = [encoder.ensure_prefix(sig)]
      # TODO: filter by topics
      events = contract.parent.client.eth_get_logs(topics: topics, address: contract.address, fromBlock: '0x0', toBlock: 'latest')
      events['result'].map do |log|
        decoded = {
          args: decoder.decode_arguments(non_indexed_inputs, log['data']),
          contract: contract.parent.name,
          event: event_name
        }
        log.merge(decoded).deep_symbolize_keys
      end
    end

    private

    def decoder
      @_decoder ||= Ethereum::Decoder.new
    end

    def encoder
      @_encoder ||= Ethereum::Encoder.new
    end
  end
end
