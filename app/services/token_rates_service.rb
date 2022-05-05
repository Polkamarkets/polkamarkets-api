class TokenRatesService
  NETWORK_TOKENS = {
    1 => 'ethereum',
    1284 => 'moonbeam',
    1285 => 'moonriver'
  }.freeze

  def get_rates(tokens, currency)
    uri = "https://api.coingecko.com/api/v3/simple/price?ids=#{tokens.join(',')}&vs_currencies=#{currency}"

    response = HTTP.get(uri)

    unless response.status.success?
      raise "TokenRatesService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s).map do |token, rate|
      [token.to_sym, rate[currency]]
    end.to_h
  end

  def get_network_rate(network_id, currency)
    token = NETWORK_TOKENS[network_id.to_i]

    return 0 if token.blank?

    Rails.cache.fetch("rates:#{token}:#{currency}", expires_in: 1.hour) do
      get_rates([token], currency).values.first
    end
  end
end
