module Bepro
  class SmartContractService
    SMART_CONTRACTS = [
      'predictionMarket',
      'predictionMarketV2',
      'erc20',
      'realitio',
      'achievements',
      'voting',
      'reward'
    ].freeze

    attr_accessor :contract_name, :contract_address, :api_url, :network_id

    def initialize(network_id:, api_url:, contract_name:, contract_address:)
      raise "Smart contract #{contract_name} not defined" unless SMART_CONTRACTS.include?(contract_name)

      @network_id = network_id
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

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )
        begin
          response = HTTP.get(uri)

          unless response.status.success?
            scope.set_tags(
              status: response.status,
              error: response.body.to_s
            )
            raise "BeproService :: Call Error"
          end
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise "BeproService :: Call Error"
        end

        begin
          JSON.parse(response.body.to_s)
        rescue => e
          # not a JSON response, return the raw response
          response.body.to_s
        end
      end
    end

    def get_events(event_name:, filter: {})
      uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      uri << "&filter=#{filter.to_json}" if filter.present?

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )

        begin
          response = HTTP.get(uri)

          unless response.status.success?
            scope.set_tags(
              status: response.status,
              error: response.body.to_s
            )
            raise "BeproService :: Events Error"
          end

          JSON.parse(response.body.to_s)
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise "BeproService :: Events Error"
        end
      end
    end

    def refresh_events(event_name:, filter: {})
      uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      uri << "&filter=#{filter.to_json}" if filter.present?

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )

        begin
          response = HTTP.post(uri)

          unless response.status.success?
            scope.set_tags(
              status: response.status,
              error: response.body.to_s
            )
            raise "BeproService :: Events Error"
          end

          JSON.parse(response.body.to_s)
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise "BeproService :: Events Error"
        end
      end
    end
  end
end
