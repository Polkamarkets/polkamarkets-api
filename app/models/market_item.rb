class MarketItem < ApplicationRecord
  validates_presence_of :title

  validates_uniqueness_of :title, scope: :market

  belongs_to :market
end
