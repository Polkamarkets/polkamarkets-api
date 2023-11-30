module Rpc
  module Streaming
    class PredictionMarketService < BaseService
      EVENT_TOPICS_MAPPING = {
        '0x57c2e8e67a3a13bc1991cd4ba3ed6733e269f1de098668140234d41dcb145ee4' => 'MarketCreated',
        '0x67a6457c8912ae1b7a9fbdfa311cbd016ba606b548bf06bc80bc751072d91bbc' => 'MarketResolved',
        '0x9dcabe311735ed0d65f0c22c5425d1f17331f94c9d0767f59e58473cf95ada61' => 'MarketActionTx',
        '0xb1bbae7680415a1349ae813ba7d737ca09df07db1f6ce058b3e0812ec15e8886' => 'MarketOutcomeShares',
        '0x1eca98f266e5348ae38d5d057a4d8e451e76672f69ac6ba4b0e3b31ea9c7eb2b' => 'MarketLiquidity',
      }.freeze

      def initialize(network_id: nil, wss_url: nil, contract_address: nil)
        super(
          network_id: network_id,
          contract_address:
            contract_address ||
              Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_contract_address) ||
              Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :prediction_market_contract_address),
          wss_url:
            wss_url ||
              Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :rpc_wss_url) ||
              Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :rpc_wss_url),
        )
      end

      def on_message(event_data)
        # deconding event from topic
        topic = event_data.dig('topics', 0)
        raise "Invalid topic: #{topic}" unless topic.present?

        event_name = EVENT_TOPICS_MAPPING[topic]
        raise "Event not found for topic: #{topic}" unless event_name.present?

        case event_name
        when 'MarketCreated'
          on_market_created(event_data)
        when 'MarketResolved'
          on_market_resolved(event_data)
        when 'MarketActionTx'
          on_market_action_tx(event_data)
        when 'MarketOutcomeShares'
          on_market_outcome_shares(event_data)
        when 'MarketLiquidity'
          on_market_liquidity(event_data)
        end
      end

      def on_market_created(event_data)
        # TODO
      end

      def on_market_resolved(event_data)
        # TODO
      end

      def on_market_action_tx(event_data)
        market_id = market_id_from_topic(event_data.dig('topics', 3))
        user = address_from_topic(event_data.dig('topics', 1))

        # refreshing market and portfolio
        market = Market.find_by(eth_market_id: market_id, network_id: network_id)
        market.refresh_cache! if market.present?

        portfolio = Portfolio.find_or_create_by(eth_address: user.downcase, network_id: network_id)
        portfolio.refresh_cache! if portfolio.present?

        # TODO: refresh actions + leaderboards
      end

      def on_market_outcome_shares(event_data)
        # doing nothing for now
      end

      def on_market_liquidity(event_data)
        # doing nothing for now
      end
    end
  end
end
