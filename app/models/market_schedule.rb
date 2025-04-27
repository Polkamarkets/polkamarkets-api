class MarketSchedule < ApplicationRecord
  validates_presence_of :frequency, :starts_at

  belongs_to :market_template

  # TODO: weekly and monthly
  enum frequency: {
    daily: 0,
  }

  def next_run
    case frequency
    when 'daily'
      today_run_at = DateTime.now.utc.beginning_of_day + starts_at.utc.seconds_since_midnight
      last_run_at.present? && last_run_at > today_run_at ? today_run_at + 1.day : today_run_at
    else
      raise "Unknown frequency: #{frequency}"
    end
  end
end
