class MinifiedMarketOutcomeSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :market_id,
    :title,
    :shares,
    :price,
    :price_charts
  )

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  def market_id
    # returning eth outcome id in chain, not db market
    object.market.eth_market_id
  end

  def price_charts
    # minified price chart with initial state (50-50 prices)
    ChartDataService::TIMEFRAMES.map do |timeframe, _duration|
      {
        timeframe: timeframe,
        prices: [
          {
            value: 0.5,
            timestamp: Time.now.beginning_of_hour.to_i,
            date: Time.now.beginning_of_hour,
          },
          {
            value: 0.5,
            timestamp: Time.now.to_i,
            date: Time.now,
          },
        ],
        change_percent: 0,
      }
    end
  end
end
