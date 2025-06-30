class MarketResolution < ApplicationRecord
  belongs_to :market
  belongs_to :market_template
  belongs_to :market_schedule

  validates :market, presence: true
  validates :market_template, presence: true
  validates :market_schedule, presence: true

  scope :pending, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
end
