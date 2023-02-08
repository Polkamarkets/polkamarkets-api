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

    def get_events(event_name:, filter: {}, paginated: false)
      base_uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      base_uri << "&filter=#{filter.to_json}" if filter.present?

      per_page = 1000
      page = 1
      finished = false
      events = []

      until finished do
        uri = paginated ? base_uri + "&perPage=#{per_page}&page=#{page}" : base_uri

        response = HTTP.get(uri)

        unless response.status.success?
          raise "BeproService #{response.status} :: #{response.body.to_s}; uri: #{uri}"
        end

        response_parsed = JSON.parse(response.body.to_s)
        events += response_parsed

        if paginated then
          finished = response_parsed.count < per_page
          page += 1
        else
          finished = true
        end
      end

      events
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
