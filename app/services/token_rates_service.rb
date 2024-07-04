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

    get_token_rate(token, currency)
  end

  def get_token_rate_from_address(address, network_id, currency)
    # setting a 1:1 rate for fantasy tokens
    return 1 if fantasy_token?(address, network_id)

    token = find_token(address, network_id)

    return 0 if token.blank?

    get_token_rate(token, currency)
  end

  def get_token_rate_from_address_at(address, network_id, currency, timestamp)
    # setting a 1:1 rate for fantasy tokens
    return 1 if fantasy_token?(address, network_id)

    token = find_token(address, network_id)

    return 0 if token.blank?

    get_token_rate_at(token, currency, timestamp)
  end

  def get_token_rate(token, currency)
    Rails.cache.fetch("rates:#{token}:#{currency}", expires_in: 24.hours) do
      get_rates([token], currency).values.first
    end
  end

  def get_token_rate_at(token, currency, timestamp)
    rates = get_token_price_history(token, currency)

    # converting timestamp to milliseconds
    timestamp = timestamp.to_i * 1000

    # fetching first rate right before timestamp
    rate = rates.reverse.find { |r| r[0] <= timestamp }

    rate.present? ? rate[1] : rates.last[1]
  end

  def get_token_price_history(token, currency)
    Rails.cache.fetch("rates:#{token}:#{currency}:history", expires_in: 24.hours) do
      uri = "https://api.coingecko.com/api/v3/coins/#{token}/market_chart?vs_currency=#{currency}&interval=daily&days=365"

      response = HTTP.get(uri)

      unless response.status.success?
        raise "TokenRatesService #{response.status} :: #{response.body.to_s}"
      end

      JSON.parse(response.body.to_s)['prices']
    end
  end

  private

  def find_token(address, network_id)
    network_tokens = Rails.application.config_for(:tokens)['networks'].dig(network_id.to_s.to_sym) || {}

    # case insensitive search by key
    token_obj = network_tokens.find { |k, v| k.to_s.downcase == address.to_s.downcase }

    token_obj ? token_obj.last : nil
  end

  def fantasy_token?(address, network_id)
    # checking land tokens
    return true if Rails.application.config_for(:ethereum).fantasy_enabled

    fantasy_tokens = Rails.application.config_for(:ethereum).fantasy_tokens

    # case insensitive search by key
    token_obj = fantasy_tokens.find { |t| t.to_s.downcase == address.to_s.downcase }

    token_obj ? true : false
  end
end
