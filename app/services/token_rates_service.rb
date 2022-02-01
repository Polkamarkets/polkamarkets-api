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
      [token.to_sym, rate['eur']]
    end.to_h
  end
end
