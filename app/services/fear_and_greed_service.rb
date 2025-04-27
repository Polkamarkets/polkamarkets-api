class FearAndGreedService
  def self.get_current_index
    get_index_history(1).first[:value]
  end

  def self.get_index_history(limit = 10)
    # Fetch the Fear and Greed Index data from the API
    response = HTTP.get("https://api.alternative.me/fng/?limit=#{limit}&format=json")
    raise "FearAndGreedService :: Error fetching data" unless response.status.success?

    # Parse the JSON response
    data = JSON.parse(response.body)
    raise "FearAndGreedService :: Unknown data format" unless data["data"].is_a?(Array) && data["data"].any?

    # Extract the relevant information
    data["data"].map do |item|
      {
        value: item["value"].to_i,
        timestamp: item["timestamp"].to_i,
        classification: item["value_classification"],
      }
    end
  end
end
