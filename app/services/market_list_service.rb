class MarketListService
  attr_accessor :uri, :list

  def initialize(uri)
    @uri = uri

    response = HTTP.get(uri)

    unless response.status.success?
      raise "MarketListService #{response.status} :: #{response.body.to_s}"
    end

    @list = JSON.parse(response.body.to_s).deep_symbolize_keys
  end

  def market_ids(network_id)
    list[:markets]
      .to_a
      .select { |market| market[:network_id] == network_id }
      .map { |market| market[:id] }
      .compact
  end

  def market_slugs(network_id)
    list[:markets]
      .to_a
      .select { |market| market[:network_id] == network_id }
      .map { |market| market[:slug] }
      .compact
  end
end
