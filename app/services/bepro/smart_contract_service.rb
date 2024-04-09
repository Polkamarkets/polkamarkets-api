module Bepro
  class SmartContractService
    SMART_CONTRACTS = [
      'predictionMarket',
      'predictionMarketV2',
      'predictionMarketV3',
      'erc20',
      'realitio',
      'achievements',
      'voting',
      'arbitration',
      'arbitrationProxy',
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

    def get_events(event_name:, filter: {}, store_events: false)
      from_block = 0
      past_events = []
      events = []

      uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      uri << "&filter=#{filter.to_json}" if filter.present?

      eth_query = EthQuery.find_or_create_by(
        contract_name: contract_name,
        network_id: network_id,
        event: event_name,
        filter: filter.to_json
      )

      if eth_query.last_block_number.present?
        uri << "&fromBlock=#{eth_query.last_block_number}"
        past_events = eth_query.eth_events.map(&:serialize_as_eth_log)
      end

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )

        begin
          response = HTTP.get(uri)
          response_body = response.body.to_s

          unless response.status.success? && !response_body.include?('server unavailable')
            scope.set_tags(
              status: response.status,
              error: response_body.to_s
            )
            raise "BeproService :: Events Error"
          end

          events = JSON.parse(response_body.to_s)
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise "BeproService :: Events Error"
        end
      end

      all_events = (past_events + events)
        .uniq { |event| [event['logIndex'] || 0, event['transactionHash']] }
        .sort_by { |event| event['blockNumber'] }

      if !store_events && events.present?
        args = [network_id, contract_name, contract_address, api_url, event_name, filter]

        # only enqueue backfill job if no same current job is running
        if !SidekiqJobFinderService.new.pending_job_running?('EthEventsWorker', args)
          EthEventsWorker.perform_async(*args)
        end

        return all_events
      end

      current_block_number = all_events.map { |event| event['blockNumber'] }.max

      events.each do |event|
        eth_event = EthEvent.find_or_initialize_by(
          event: event_name,
          contract_name: contract_name,
          network_id: network_id,
          address: contract_address,
          transaction_hash: event['transactionHash'],
          log_index: event['logIndex'] || 0,
        )
        eth_event.update!(
          block_hash: event['blockHash'],
          block_number: event['blockNumber'],
          removed: event['removed'],
          transaction_index: event['transactionIndex'],
          signature: event['signature'],
          data: event['returnValues'],
          raw_data: event['raw'],
        )
        eth_query.eth_events << eth_event if eth_query.eth_event_ids.exclude?(eth_event.id)
      end

      eth_query.last_block_number = current_block_number + 1 if current_block_number.present?
      eth_query.save!

      all_events
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
          response_body = response.body.to_s

          unless response.status.success? && !response_body.include?('server unavailable')
            scope.set_tags(
              status: response.status,
              error: response_body.to_s
            )
            raise "BeproService :: Events Error"
          end

          JSON.parse(response_body.to_s)
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
