class Market < ApplicationRecord
  validates_presence_of :title, :category

  has_many :outcomes, class_name: "MarketOutcome", dependent: :destroy

  validates :outcomes, length: { minimum: 2, maximum: 2 } # currently supporting only binary markets

  scope :published, -> { where('published_at < ?', DateTime.now).where.not(eth_market_id: nil) }
  scope :open, -> { published.where('expires_at > ?', DateTime.now) }
  scope :resolved, -> { published.where('expires_at < ?', DateTime.now) }

  def eth_data(reload = false)
    return nil if eth_market_id.blank?

    return @eth_data if @eth_data.present? && !reload

    Rails.cache.fetch("markets:#{eth_market_id}", expires_in: 24.hours, force: reload) do
      @eth_data = Ethereum::PredictionMarketContractService.new.get_market(eth_market_id)
    end
  end

  def outcome_prices(timeframe, candles = 12)
    return nil if eth_market_id.blank?

    market_prices = Ethereum::PredictionMarketContractService.new.get_price_events(eth_market_id)

    grouped_market_prices = market_prices.group_by { |price| price[:outcome_id] }.map do |outcome_id, prices|
      chart_data_service = ChartDataService.new(prices, :price)
      # returning in hash form
      [outcome_id, chart_data_service.chart_data_for(timeframe, candles)]
    end.to_h
  end
end
