module Subgraph
  class QueryService
    SUBGRAPHS = [
      # TO ADD
    ].freeze

    attr_accessor :subgraph_url

    def initialize(subgraph_url:, subgraph_name:)
      raise "Subgraph #{subgraph_name} not defined" unless SUBGRAPHS.include?(subgraph_name)

      @subgraph_name = subgraph_name
      @subgraph_url = subgraph_url
    end

    def query(query:)
      response = HTTP.post(subgraph_url, json: { query: query })

      unless response.status.success?
        raise "SubgraphService #{response.status} :: #{response.body.to_s}; uri: #{uri}"
      end

      begin
        JSON.parse(response.body.to_s)['data']
      rescue => e
        response.body.to_s
      end
    end
  end
end
