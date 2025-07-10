module Bepro
  class SmartContractService
    SMART_CONTRACTS = [
      'predictionMarket',
      'predictionMarketV2',
      'predictionMarketV3',
      'predictionMarketV3_2',
      'predictionMarketV3Manager',
      'predictionMarketV3Controller',
      'predictionMarketV3Querier',
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

      @api_public_key = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_public_key)
      @admin_private_key = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :admin_private_key)
    end

    def call(method:, args: [])
      if args.kind_of?(Array)
        args = args.compact.join(',')
      end

      uri = api_url + "/call?contract=#{contract_name}&address=#{contract_address}&method=#{method}"
      puts uri
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

    def execute(method:, args: [])
      uri = api_url + "/execute"

      public_key = OpenSSL::PKey::RSA.new(@api_public_key.gsub("\\n", "\n"))

      body = {
        contract: contract_name,
        address: contract_address,
        method: method,
        args: args,
        privateKey: Base64.encode64(public_key.public_encrypt(@admin_private_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)),
        timestamp: Base64.encode64(public_key.public_encrypt((Time.now.to_i * 1000).to_s, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)),
      }

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )
        begin
          response = HTTP.post(uri, json: body)

          unless response.status.success?
            scope.set_tags(
              status: response.status,
              error: response.body.to_s
            )
            raise "BeproService :: Call Error #{response.body.to_s}"
          end
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise "BeproService :: Call Error #{e.message}"
        end

        begin
          JSON.parse(response.body.to_s)
        rescue => e
          # not a JSON response, return the raw response
          response.body.to_s
        end
      end
    end

    def executor_address
      raise "Executor not defined" if @admin_private_key.blank?

      Eth::Key.new(priv: @admin_private_key).address.to_s
    end

    def get_events(event_name:, filter: {}, store_events: false, from_block: nil, to_block: nil)
      past_events = []
      events = []

      # stringifying filter
      filter.deep_stringify_keys!

      uri = api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
      uri << "&filter=#{filter.to_json}" if filter.present?

      begin
        eth_query = EthQuery.find_or_create_by(
          contract_name: contract_name,
          network_id: network_id,
          event: event_name,
          filter: filter.to_json,
          contract_address: contract_address,
          api_url: api_url
        )
      rescue => e
        # concurrent creation, retrying
        eth_query = EthQuery.find_or_create_by(
          contract_name: contract_name,
          network_id: network_id,
          event: event_name,
          filter: filter.to_json,
          contract_address: contract_address,
          api_url: api_url
        )
      end

      if from_block.present? || to_block.present?
        uri << "&fromBlock=#{from_block}" if from_block.present?
        uri << "&toBlock=#{to_block}" if to_block.present?
      elsif eth_query.last_block_number.present?
        uri << "&fromBlock=#{eth_query.last_block_number}"
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

      # custom range provided, no need to store events
      return events if from_block.present? || to_block.present?

      if store_events
        return [] if events.blank?

        current_block_number = events.map { |event| event['blockNumber'] }.max

        begin
          events.each_with_index do |event, index|
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

            # periodically updating the last block number
            if index % 1000 == 0 &&
              (eth_query.reload.last_block_number.blank? || event['blockNumber'] > eth_query.last_block_number)
              eth_query.update!(last_block_number: event['blockNumber'])
            end
          end

          eth_query.last_block_number = current_block_number + 1 if current_block_number.present?
          eth_query.save!
        rescue ActiveRecord::RecordNotUnique
          # concurrent creation, ignoring
        end

        return events
      end

      if eth_query.last_block_number.present?
        # batching for optimization purposes
        eth_query.eth_events.except_raw_data.find_each(batch_size: 10000).with_index do |event, i|
          past_events << event.serialize_as_eth_log
          GC.start if i % 1000 == 0
        end
      end

      all_events = (past_events + events)
        .uniq { |event| [event['logIndex'] || 0, event['transactionHash']] }
        .sort_by { |event| event['blockNumber'] }

      if events.present?
        args = [network_id, contract_name, contract_address, api_url, event_name, filter]

        # only enqueue backfill job if no same current job is running
        if !eth_query.pending_index_running?
          EthEventsWorker.perform_async(*args)
        end
      end

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
