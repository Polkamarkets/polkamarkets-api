class MarketOutcome < ApplicationRecord
  include Immutable
  include Cloudflareable

  validates_presence_of :title, :market

  validates_uniqueness_of :title, scope: :market
  validates_uniqueness_of :eth_market_id, scope: :market

  belongs_to :market, inverse_of: :outcomes

  IMMUTABLE_FIELDS = [:title]

  def eth_data(refresh: false)
    return nil if eth_market_id.blank? || market.eth_market_id.blank?

    return @eth_data if @eth_data.present? && !refresh

    market_eth_data = market.eth_data(refresh: refresh)
    @eth_data = market_eth_data[:outcomes].find { |outcome| outcome[:id].to_s == eth_market_id.to_s }
  end

  def price_charts(refresh: false, simplified: false)
    return nil if eth_market_id.blank? || market.eth_market_id.blank?

    timeframes = simplified ? [ChartDataService::DEFAULT_TIMEFRAME] : ChartDataService::TIMEFRAMES.keys

    timeframes.map do |timeframe|
      expires_at = ChartDataService.next_datetime_for(timeframe)
      # caching chart until next candlestick
      expires_in = market.should_refresh_cache? ? (expires_at.to_i - DateTime.now.to_i).seconds : nil

      price_chart =
        Rails.cache.fetch(
          "markets:network_#{market.network_id}:#{market.eth_market_id}:outcomes:#{eth_market_id}:chart:#{timeframe}",
          expires_in: expires_in,
          force: refresh
        ) do
          outcome_prices = market.outcome_prices(timeframe, end_at_resolved_at: true)
          # defaulting to [] if market is not in chain
          outcome_prices[eth_market_id] || []
        end

      # changing value of last item for current price
      if price_chart.present?
        # calculating next timestamp for current timeframe
        next_timestamp = ChartDataService.next_datetime_for(timeframe, market.resolved? ? market.resolved_at : nil).to_i
        # setting to now if next timestamp is in the future
        next_timestamp = DateTime.now.to_i if next_timestamp > DateTime.now.to_i

        price_chart.last[:value] = price
        price_chart.last[:timestamp] = next_timestamp
        price_chart.last[:date] = Time.at(next_timestamp)
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

  def image_ipfs_hash
    return self[:image_ipfs_hash] if eth_data.blank?

    eth_data[:image_hash]
  end

  def price
    return draft_price if eth_data.blank?

    eth_data[:price]
  end

  def closing_price(refresh: false)
    return price if market.state == 'closed'

    return nil unless market.resolved?

    Rails.cache.fetch(
      "markets:network_#{market.network_id}:#{market.eth_market_id}:outcomes:#{eth_market_id}:closing_price",
      force: refresh
    ) do
      outcome_prices = market.market_prices(refresh: refresh).select do |price|
        price[:timestamp] < market.expires_at.to_i
        price[:outcome_id] == eth_market_id
      end

      outcome_prices.blank? ? nil : outcome_prices.last[:price]
    end
  end

  def price_change_24h(refresh: false)
    Rails.cache.fetch(
      "markets:network_#{market.network_id}:#{market.eth_market_id}:outcomes:#{eth_market_id}:price_change_24h",
      force: refresh
    ) do
      pc = price_charts
      pc.blank? ? 0.0 : pc.find { |chart| chart[:timeframe] == '24h' }[:change_percent]
    end
  end

  def shares
    return nil if eth_data.blank?

    eth_data[:shares]
  end
end
