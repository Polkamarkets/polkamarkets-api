class MarketOutcome < ApplicationRecord
  validates_presence_of :title

  validates_uniqueness_of :title, scope: :market
  validates_uniqueness_of :eth_market_id, scope: :market

  belongs_to :market

  def eth_data(reload = false)
    return nil if eth_market_id.blank? || market.eth_market_id.blank?

    return @eth_data if @eth_data.present? && !reload

    market_eth_data = market.eth_data
    @eth_data = market_eth_data[:outcomes].find { |outcome| outcome[:id].to_s == eth_market_id.to_s }
  end
end
