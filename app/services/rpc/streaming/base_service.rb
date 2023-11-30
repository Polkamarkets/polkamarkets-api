module Rpc
  module Streaming
    class BaseService
      attr_accessor :contract_address, :wss_url, :network_id

      def initialize(network_id:, wss_url:, contract_address:)
        raise "Contract address not defined" unless contract_address.present?
        raise "WSS URL not defined" unless wss_url.present?

        @network_id = network_id
        @contract_address = contract_address
        @wss_url = wss_url
      end

      def params
        {
          jsonrpc: '2.0',
          id: 1,
          method: 'eth_subscribe',
          params: ['logs', { address: contract_address }]
        }
      end

      def subscribe
        EM.run {
          ws_client.on :open do |event|
            ws_client.send(params.to_json)
          end

          ws_client.on :message do |event|
            begin
              response = JSON.parse(event.data)
              next unless response['method'] == 'eth_subscription'

              raise "Invalid response: #{response}" unless response.dig('params', 'result').present?

              on_message(response.dig('params', 'result'))
            rescue => e
              # should be non-blocking, sending to Sentry
              Sentry.capture_exception(e)
            end
          end

          ws_client.on :close do |event|
            # TODO
          end
        }
      end

      def on_message(event_data)
        raise 'To be implemented by subclasses'
      end

      private

      def ws_client
        @_ws_client ||= Faye::WebSocket::Client.new(wss_url)
      end

      def market_id_from_topic(topic)
        topic.to_i(16)
      end

      def address_from_topic(topic)
        "0x#{topic[26..-1]}"
      end
    end
  end
end
