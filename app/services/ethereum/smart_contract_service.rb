module Ethereum
  class SmartContractService
    include BigNumberHelper

    attr_accessor :client, :contract

    def initialize(url: nil, contract_address: nil)
      # variables to define in child classes
      raise "contract_name is not defined!" if @contract_name.blank?
      raise "contract_address is not defined!" if @contract_address.blank?

      # chain parameters can be sent via params and env vars
      url ||= Config.ethereum.url
      contract_address ||= @contract_address

      @client = Ethereum::HttpClient.new(url)
      abi = JSON.parse(File.read("app/contracts/#{@contract_name}.json"))['abi']
      @contract = Ethereum::Contract.create(name: @contract_name, address: contract_address, abi: abi, client: client)
    end

    def get_events(event_name, args = [])
      event_abi = contract.abi.find { |abi| abi['name'] == event_name.to_s }
      event_inputs = event_abi['inputs'].map { |input| OpenStruct.new(input) }

      # indexed and non indexed inputs are store differently
      indexed_inputs = event_inputs.select(&:indexed)
      non_indexed_inputs = event_inputs.reject(&:indexed)

      sig = contract.parent.events.find { |e| e.name.to_s == event_name.to_s }.signature

      topics = [encoder.ensure_prefix(sig)]
      # filtering by indexed arguments (argument order has to be followed)
      if args.present?
        args.each_with_index do |arg, index|
          encoded_argument =
            if arg.blank?
              nil
            else
              encoder.ensure_prefix(encoder.encode_arguments([indexed_inputs[index]], [arg]))
            end

          topics << encoded_argument
        end
      end

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

    def call_raw_function(function_name, function_args)
      function = contract.parent.functions.find { |f| f.name == function_name }
      abi = contract.abi.find { |abi| abi['name'] == function_name }

      inputs = abi['inputs'].map { |input| OpenStruct.new(input) }

      input = encoder.encode_arguments(inputs, function_args)
      data = encoder.ensure_prefix(function.signature + input)

      tx_args = {
        to: contract.address,
        data: data,
        value: '0x0',
      }

      tx = client.eth_call(tx_args)
      decoder.decode_arguments(function.outputs, tx['result']).flatten
    end

    def call_payable_function(function_name, function_args, value, from_address)
      function = contract.parent.functions.find { |f| f.name == function_name }
      abi = contract.abi.find { |abi| abi['name'] == function_name && abi['inputs'].count == function_args.count }

      inputs = abi['inputs'].map { |input| OpenStruct.new(input) }

      input = encoder.encode_arguments(inputs, function_args)
      data = encoder.ensure_prefix(function.signature + input)

      tx_args = {
        from: from_address,
        to: contract.address,
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
