class ChartDataService
  attr_accessor :items_arr, :item_key

  DEFAULT_TIMEFRAME = '7d'

  TIMEFRAMES = {
    "24h" => 24.hours,
    "7d" => 7.days,
    "30d" => 30.days,
    "all" => 30.days # default value, is overwritten when timeframe is higher
  }

  def initialize(items_arr, item_key)
    # sorting array by timestamp (high -> low)
    @items_arr = items_arr.sort_by { |item| -item[:timestamp] }
    @item_key = item_key
  end

  def chart_data_for(timeframe, end_timestamp = nil)
    timestamps = self.class.timestamps_for(timeframe, items_arr.last&.fetch(:timestamp), end_timestamp)

    values_at_timestamps(timestamps)
  end

  def value_at(timestamp)
    # taking into assumption that price_arr was previously sorted (high -> low)
    items_arr.find { |item| item[:timestamp] < timestamp }
  end

  def self.timestamps_for(timeframe, start_timestamp = nil, end_timestamp = nil)
    # returns previous datetime for each candle (last one corresponding to now)
    now = end_timestamp || DateTime.now.to_i
    initial_datetime = previous_datetime_for(timeframe, now)

    # adding now as last candle
    timestamps = [now]

    # calculating number of candles
    step = step_for(timeframe)
    points = TIMEFRAMES[timeframe] / step

    # 'all' timeframe step / points can be recalculated
    if timeframe == 'all' && start_timestamp
      step_days = ((now.to_i - start_timestamp.to_i) / TIMEFRAMES[timeframe].to_f).ceil

      step = step_days.days
    end

    # subracting one candle (last candle -> now)
    points.times do |index|
      timestamp = (initial_datetime - step * index).to_i

      timestamps.push(timestamp)
    end

    timestamps
  end

  def values_at_timestamps(timestamps)
    # taking into assumption that price_arr was previously sorted (high -> low)
    values = []

    for timestamp in timestamps do
      item = value_at(timestamp)

      if item.blank?
        # no more data backwards - pulling first item and stopping backfill
        item = items_arr.last
        values.push({ value: item[item_key], timestamp: item[:timestamp], date: Time.at(item[:timestamp]) })
        break
      end

      values.push({ value: item[item_key], timestamp: timestamp, date: Time.at(timestamp) })
    end

    values.reverse
  end

  def self.step_for(timeframe)
    case timeframe
    when '24h' # 24 candles
      1.hour
    when '7d' # 14 candles
      12.hours
    when '30d' # 30 candles
      1.day
    when 'all'
      1.day
    else
      raise "ChartDataService :: Timeframe #{timeframe} not supported"
    end
  end

  def self.previous_datetime_for(timeframe, timestamp = nil)
    datetime = Time.at(timestamp || DateTime.now.to_i)

    # TODO: double check timezones issue
    case timeframe
    when '24h'
      datetime.beginning_of_hour
    when '7d'
      datetime = datetime.beginning_of_hour
      # making sure hour is a multiple of 12
      until datetime.hour % 12 == 0 do
        datetime = datetime - 1.hour
      end
      datetime
    when '30d'
      datetime.beginning_of_day
    when 'all'
      datetime.beginning_of_day
    else
      raise "ChartDataService :: Timeframe #{timeframe} not supported"
    end
  end

  def self.next_datetime_for(timeframe, timestamp = nil)
    previous_datetime_for(timeframe, timestamp) + step_for(timeframe)
  end
end
