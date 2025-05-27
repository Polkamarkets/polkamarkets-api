class BinanceApiService
  def self.get_price_events(symbol, interval, limit = 10, start_time = nil, end_time = nil)
    uri = "https://api.binance.com/api/v3/klines?symbol=#{symbol}&interval=#{interval}&limit=#{limit}"
    uri += "&startTime=#{start_time.to_i * 1000}" if start_time
    uri += "&endTime=#{end_time.to_i * 1000}" if end_time

    response = HTTP.get(uri)
    raise "BinanceApiService :: Error fetching data" unless response.status.success?

    # Parse the JSON response
    data = JSON.parse(response.body)

    # Extract the relevant information
    data.map do |item|
      {
        open_time: item[0].to_i,
        open: item[1].to_f,
        high: item[2].to_f,
        low: item[3].to_f,
        close: item[4].to_f,
        volume: item[5].to_f,
        close_time: item[6].to_i,
      }
    end
  end
end
