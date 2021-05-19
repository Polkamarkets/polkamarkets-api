class MarketOutcome < ApplicationRecord
  include Immutable

  validates_presence_of :title, :market

  validates_uniqueness_of :title, scope: :market
  validates_uniqueness_of :eth_market_id, scope: :market

  belongs_to :market, inverse_of: :outcomes

  IMMUTABLE_FIELDS = [:title]

  def eth_data(refresh = false)
    return nil if eth_market_id.blank? || market.eth_market_id.blank?

    return @eth_data if @eth_data.present? && !refresh

    market_eth_data = market.eth_data(refresh)
    @eth_data = market_eth_data[:outcomes].find { |outcome| outcome[:id].to_s == eth_market_id.to_s }
  end

  def price_charts(refresh: false)
    return nil if eth_market_id.blank? || market.eth_market_id.blank?

    timeframes = ChartDataService::TIMEFRAMES.keys

    timeframes.map do |timeframe|
      expires_at = ChartDataService.next_datetime_for(timeframe)
      # caching chart until next candlestick
      expires_in = expires_at.to_i - DateTime.now.to_i

      price_chart =
        Rails.cache.fetch(
          "markets:#{market.eth_market_id}:outcomes:#{eth_market_id}:chart:#{timeframe}",
          expires_in: expires_in.seconds,
          force: refresh
        ) do
          outcome_prices = market.outcome_prices(timeframe)
          # defaulting to [] if market is not in chain
          outcome_prices[eth_market_id] || []
        end

      # changing value of last item for current price
      if price_chart.present?
        price_chart.last[:value] = price
        price_chart.last[:timestamp] = DateTime.now.to_i if price_chart.present?
        change_percent = (price - price_chart.first[:value]) / price_chart.first[:value]
      else
        price_chart = [{
          value: price,
          timestamp: Time.now.to_i,
          date: Time.now,
        }]
        change_percent = 0.0
      end

      {
        timeframe: timeframe,
        prices: price_chart,
        change_percent: change_percent
      }
    end
  end

  def price
    return nil if eth_data.blank?

    eth_data[:price]
  end

  def shares
    return nil if eth_data.blank?

    eth_data[:shares]
  end
end
