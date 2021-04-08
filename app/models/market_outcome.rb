class MarketOutcome < ApplicationRecord
  validates_presence_of :title

  validates_uniqueness_of :title, scope: :market
  validates_uniqueness_of :eth_market_id, scope: :market

  belongs_to :market
end
