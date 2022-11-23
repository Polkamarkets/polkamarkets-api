module Subgraph
  class PredictionMarketResolverService < QueryService
    include BigNumberHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        subgraph_name: 'predictionMarketResolver',
        subgraph_url:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_resolver_subgraph)
      )
    end

    def get_markets_resolved
      query = "{ marketResolveds { marketId outcomeId timestamp } }"

      response = query(query: query)

      return [] if response.blank?

      response['marketResolveds'].map do |market_resolved|
        {
          market_id: market_resolved['marketId'].to_i,
          outcome_id: market_resolved['outcomeId'].to_i,
          timestamp: market_resolved['timestamp'].to_i
        }
      end
    end
  end
end
