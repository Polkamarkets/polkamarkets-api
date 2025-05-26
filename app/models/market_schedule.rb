class MarketSchedule < ApplicationRecord
  validates_presence_of :frequency, :starts_at, :expires_at, :resolves_at

  belongs_to :market_template

  # TODO: weekly and monthly
  enum frequency: {
    daily: 0,
    weekly: 1,
  }

  def next_run
    case frequency
    when 'daily'
      today_run_at = DateTime.now.utc.beginning_of_day + starts_at.utc.seconds_since_midnight
      last_run_at.present? && last_run_at > today_run_at ? today_run_at + 1.day : today_run_at
    when 'weekly'
      week_run_at = DateTime.now.utc.beginning_of_week + (starts_at.utc.wday - 1).days + starts_at.utc.seconds_since_midnight
      last_run_at.present? && last_run_at > week_run_at ? week_run_at + 1.week : week_run_at
    else
      raise "Unknown frequency: #{frequency}"
    end
  end

  def next_run_expires_at
    return nil if expires_at.blank?

    (next_run + (expires_at - starts_at)).in_time_zone(expires_at.time_zone)
  end

  def next_run_resolves_at
    return nil if resolves_at.blank?

    (next_run + (resolves_at - starts_at)).in_time_zone(resolves_at.time_zone)
  end

  def next_run_variables
    {
      close_date: next_run_expires_at&.strftime("%B %-d, %Y"),
      close_date_short: next_run_expires_at&.strftime("%B %-d"),
      close_date_full: next_run_expires_at&.strftime("%B %-d, %Y, at %-I:%M%P"),
      resolution_date: next_run_resolves_at&.strftime("%B %-d, %Y"),
      resolution_date_short: next_run_resolves_at&.strftime("%B %-d"),
      resolution_date_full: next_run_resolves_at&.strftime("%B %-d, %Y, at %-I:%M%P"),
    }
  end
end
