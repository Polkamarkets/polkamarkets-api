class MarketSchedule < ApplicationRecord
  include Schedulable

  belongs_to :market_template

  has_and_belongs_to_many :market_schedules
end
