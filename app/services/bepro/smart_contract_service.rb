module Bepro
  class SmartContractService
    SMART_CONTRACTS = [
      'predictionMarket',
      'erc20',
      'realitio',
      'achievements',
      'voting'
    ].freeze

    attr_accessor :contract_name, :contract_address, :api_url

    def initialize(api_url:, contract_name:, contract_address:)
      raise "Smart contract #{contract_name} not defined" unless SMART_CONTRACTS.include?(contract_name)

      @contract_name = contract_name
      @contract_address = contract_address
      @api_url = api_url
    end

    def call(method:, args: [])
      if args.kind_of?(Array)
        args = args.compact.join(',')
      end

      uri = api_url + "/call?contract=#{contract_name}&address=#{contract_address}&method=#{method}"
      uri << "&args=#{args}" if args.present?

      response = HTTP.get(uri)

      unless response.status.success?
        raise "BeproService #{response.status} :: #{response.body.to_s}; uri: #{uri}"
      end

      begin
        JSON.parse(response.body.to_s)
      rescue => e
        response.body.to_s
      end
    end

    def get_events(event_name:, filter: {})
      uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      uri << "&filter=#{filter.to_json}" if filter.present?

      response = HTTP.get(uri)

      unless response.status.success?
        raise "BeproService #{response.status} :: #{response.body.to_s}; uri: #{uri}"
      end

      JSON.parse(response.body.to_s)
    end

    def refresh_events(event_name:, filter: {})
      uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      uri << "&filter=#{filter.to_json}" if filter.present?

      response = HTTP.post(uri)

      unless response.status.success?
        raise "BeproService #{response.status} :: #{response.body.to_s}; uri: #{uri}"
      end

      true
    end
  end
end
