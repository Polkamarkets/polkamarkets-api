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
          puts "HERE: #{wss_url}"
          puts params
          ws_client = Faye::WebSocket::Client.new(wss_url)

          ws_client.on :open do |event|
            ws_client.send(params.to_json)
          end

          ws_client.on :message do |event|
            puts "Received message on service!"
            puts event.data

            response = JSON.parse(event.data)
            next unless response['method'] == 'eth_subscription'

            raise "Invalid response: #{response}" unless response.dig('params', 'result').present?

            on_message(response.dig('params', 'result'))
          end

          ws_client.on :close do |event|
            # TODO
          end
        }
      end

      def on_message(event_data)
        raise 'To be implemented by subclasses'
      end
    end
  end
end
