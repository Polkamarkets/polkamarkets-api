class MarketSchedule < ApplicationRecord
  validates_presence_of :frequency, :starts_at

  belongs_to :market_template

  # TODO: weekly and monthly
  enum frequency: {
    daily: 0,
  }

  def next_run
    return starts_at if last_run_at.blank?

    case frequency
    when 'daily'
      last_run_at + 1.day
    else
      raise "Unknown frequency: #{frequency}"
    end
  end
end
