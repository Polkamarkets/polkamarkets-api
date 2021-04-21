module Ethereum
  class SmartContractService
    include BigNumberHelper

    attr_accessor :client, :contract

    def initialize(url: nil, contract_address: nil)
      # chain parameters can be sent via params and env vars
      url ||= Config.ethereum.url
      contract_address ||= Config.ethereum.contract_address

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

    def call_payable_function(function_name, function_args, value)
      function = contract.parent.functions.find { |f| f.name == function_name }
      abi = contract.abi.find { |abi| abi['name'] == function_name }

      inputs = abi['inputs'].map { |input| OpenStruct.new(input) }

      input = encoder.encode_arguments(inputs, function_args)
      data = encoder.ensure_prefix(function.signature + input)

      tx_args = {
        from: Config.ethereum.oracle_address,
        to: Config.ethereum.contract_address,
        data: data,
        value: value,
        nonce: client.get_nonce(key.address),
        gas_limit: client.gas_limit,
        gas_price: client.gas_price
      }
      tx = Eth::Tx.new(tx_args)
      tx.sign(key)

      client.eth_send_raw_transaction(tx.hex)
    end

    private

    def decoder
      @_decoder ||= Ethereum::Decoder.new
    end

    def encoder
      @_encoder ||= Ethereum::Encoder.new
    end

    def key
      @_key ||= Eth::Key.new priv: Config.ethereum.oracle_private_key
    end
  end
end
